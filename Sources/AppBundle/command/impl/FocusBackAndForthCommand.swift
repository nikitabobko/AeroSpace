import AppKit
import Common

struct FocusBackAndForthCommand: Command {
    let args: FocusBackAndForthCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch prevFocus {
            case let prevFocus?: setFocus(to: prevFocus)
            case nil: io.err("Prev window has been closed")
        }
    }
}
