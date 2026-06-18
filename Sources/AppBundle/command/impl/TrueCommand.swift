import AppKit
import Common

struct TrueCommand: Command {
    let args: TrueCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> ConditionalExitCode { ._true }
}
