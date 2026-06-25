import AppKit
import Common

struct TestNotCommand: Command {
    let args: TestNotCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> ConditionalExitCode {
        switch await TestCommand(args: args.testArgs).run(env, io) {
            case ._false: ._true
            case ._true: ._false
            case .fail: .fail
        }
    }
}
