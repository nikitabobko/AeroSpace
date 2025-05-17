import Common

struct NoopCommand: Command {
    let args: NoopCmdArgs

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        // No operation, so we indicate success.
        return true
    }
}
