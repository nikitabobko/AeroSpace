import Common

struct CommandCenterCommand: Command {
    let args: CommandCenterCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        if CommandCenter.shared.isOpen {
            await CommandCenter.shared.close(restoreFocus: true)
            return .succ
        }
        guard let snapshot = try? await CommandCenterSnapshot.capture(.nonCancellable) else { return .fail(io.err(bugPrompt())) }
        CommandCenter.shared.open(snapshot)
        return .succ
    }
}
