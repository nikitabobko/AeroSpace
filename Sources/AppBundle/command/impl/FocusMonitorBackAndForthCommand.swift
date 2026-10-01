import AppKit
import Common

struct FocusMonitorBackAndForthCommand: Command {
    let args: FocusMonitorBackAndForthCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        switch prevFocusedMonitor {
            case let monitor?: .from(bool: monitor.activeWorkspace.focusWorkspace())
            case nil: .fail(io.err("Can't find prev monitor"))
        }
    }
}
