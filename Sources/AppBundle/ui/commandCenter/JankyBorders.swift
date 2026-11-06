import Common
import Darwin
import Foundation

/// The colors and the border width of a running JankyBorders (https://github.com/FelixKratz/JankyBorders).
///
/// JankyBorders draws the borders around the real windows. When it runs, the command center borrows its colors
/// and its width, so the focused tile looks the way the focused window looks on the desktop.
struct JankyBorders: Equatable {
    var activeColor: ArgbColor? = nil
    var inactiveColor: ArgbColor? = nil
    var width: CGFloat? = nil

    /// The settings of the running `borders` process of the current user, or nil if it doesn't run
    static func detect() -> JankyBorders? {
        runningBordersArgs().map(parse)
    }

    /// Parses `borders` command line arguments: `active_color=0xffe2e2e3 inactive_color=0xff494949 width=4.0`.
    /// Gradients and other values the command center can't draw are ignored
    static func parse(_ args: [String]) -> JankyBorders {
        var result = JankyBorders()
        for arg in args {
            guard let eq = arg.firstIndex(of: "=") else { continue }
            let key = String(arg[..<eq])
            let value = String(arg[arg.index(after: eq)...])
            switch key {
                case "active_color": result.activeColor = try? ArgbColor.parse(value).get()
                case "inactive_color": result.inactiveColor = try? ArgbColor.parse(value).get()
                case "width": result.width = Double(value).map { CGFloat($0) }
                default: break
            }
        }
        return result
    }

    /// Arguments of the first `borders` process owned by the current user, without the executable
    private static func runningBordersArgs() -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(getuid())]
        var size = 0
        guard unsafe sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        let stride = unsafe MemoryLayout<kinfo_proc>.stride
        var procs = unsafe [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
        guard unsafe sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else { return nil }
        let pids = unsafe procs.prefix(size / stride)
            .filter { proc in unsafe withUnsafePointer(to: proc.kp_proc.p_comm) { unsafe String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) } == "borders" }
            .map(\.kp_proc.p_pid)
        for pid in pids {
            if let args = processArgs(pid), !args.isEmpty { return args }
        }
        return nil
    }

    /// KERN_PROCARGS2: argc (Int32), the executable path, NUL padding, then the NUL-separated arguments
    private static func processArgs(_ pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard unsafe sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard unsafe sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }
        let argc = Int(buffer.withUnsafeBytes { unsafe $0.load(as: Int32.self) })
        var strings = buffer[MemoryLayout<Int32>.size ..< size]
            .split(separator: 0, omittingEmptySubsequences: true)
            .map { String(decoding: $0, as: UTF8.self) }
        guard !strings.isEmpty else { return nil }
        strings.removeFirst() // The executable path
        return Array(strings.prefix(argc).dropFirst()) // argv[0]
    }
}
