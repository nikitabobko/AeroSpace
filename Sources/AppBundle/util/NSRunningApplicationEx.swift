import AppKit

extension NSRunningApplication {
    var idForDebug: String {
        "PID: \(processIdentifier) ID: \(bundleIdentifier ?? executableURL?.description ?? "")"
    }
}
