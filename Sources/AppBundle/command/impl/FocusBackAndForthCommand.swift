import AppKit
import Common

struct FocusBackAndForthCommand: Command {
    let args: FocusBackAndForthCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        switch prevFocus {
            case let prevFocus?: .from(bool: setFocus(to: prevFocus))
            case nil: .fail(io.err("Prev window has been closed"))
        }
    }
}
