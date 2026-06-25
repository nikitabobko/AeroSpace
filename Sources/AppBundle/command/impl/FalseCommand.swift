import AppKit
import Common

struct FalseCommand: Command {
    let args: FalseCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> ConditionalExitCode { ._false }
}
