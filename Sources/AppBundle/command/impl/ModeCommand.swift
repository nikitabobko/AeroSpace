import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        let targetMode = args.targetMode.val

        if isAutoMode(targetMode) {
            isManualModeOverride = false
            if targetMode == mainModeId {
                if let appMode = lastAutoAppMode {
                    try await activateMode(appMode)
                    return .succ
                }
            }
        } else {
            isManualModeOverride = true
        }

        try await activateMode(targetMode)
        return .succ
    }
}
