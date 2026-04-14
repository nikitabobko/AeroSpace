import AppKit
import Common

struct FalseCommand: Command {
    let args: FalseCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> ConditionalExitCode { ._false }
}
