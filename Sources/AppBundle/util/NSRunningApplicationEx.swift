import AppKit
import Darwin

extension NSRunningApplication {
    var idForDebug: String {
        "PID: \(processIdentifier) ID: \(bundleIdentifier ?? executableURL?.description ?? "")"
    }

    /// processIdentifier as reported by LaunchServices, falling back to a live
    /// process lookup when LaunchServices reports an invalid PID.
    /// Some apps (e.g. Xcode 27 DeviceHub, launched via DevicesTrampoline) are
    /// reported with processIdentifier == -1. AXUIElementCreateApplication and
    /// AXObserverCreate fail for such PIDs, so the app can never be registered.
    var resolvedProcessIdentifier: pid_t {
        let reported = processIdentifier
        if reported > 0 { return reported }
        guard let execPath = executableURL?.path else { return reported }
        let capacity = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0))
        guard capacity > 0 else { return reported }
        var pids = [pid_t](repeating: 0, count: capacity)
        let bytes = pids.withUnsafeMutableBytes { buf -> Int32 in
            guard let base = buf.baseAddress else { return -1 }
            return unsafe proc_listpids(UInt32(PROC_ALL_PIDS), 0, base, Int32(buf.count))
        }
        guard bytes > 0 else { return reported }
        let found = Int(bytes) / MemoryLayout<pid_t>.size
        // PROC_PIDPATHINFO_MAXSIZE (4 * MAXPATHLEN) is not importable into Swift
        let pathBufSize = 4 * 1024
        for i in 0 ..< min(found, pids.count) {
            let candidate = pids[i]
            guard candidate > 0 && candidate != myPid else { continue }
            var path = [CChar](repeating: 0, count: pathBufSize)
            let len = path.withUnsafeMutableBufferPointer { buf -> Int32 in
                guard let base = buf.baseAddress else { return -1 }
                return unsafe proc_pidpath(candidate, base, UInt32(buf.count))
            }
            guard len > 0 else { continue }
            let candidatePath = String(decoding: path.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard candidatePath == execPath else { continue }
            return candidate
        }
        return reported
    }
}
