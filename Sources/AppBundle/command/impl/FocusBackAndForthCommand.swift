import AppKit
import Common

struct FocusBackAndForthCommand: Command {
    let args: FocusBackAndForthCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        if let prevFocus {
            return setFocus(to: prevFocus)
        } else {
            return io.err("Prev window has been closed")
        }
    }
}
