import AppKit
import Common

struct SleepCommand: Command {
    let args: SleepCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        // Sleep for the specified milliseconds
        try await Task.sleep(for: .milliseconds(Int64(args.milliseconds.val)))
        return true
    }
}
