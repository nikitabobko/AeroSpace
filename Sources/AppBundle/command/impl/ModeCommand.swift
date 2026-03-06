import AppKit
import Common

struct ModeCommand: Command {
    let args: ModeCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let targetMode = args.targetMode.val

        if isAutoMode(targetMode) {
            // Returning to auto-mode clears manual override
            isManualModeOverride = false
            if targetMode == mainModeId {
                // Check if we should switch to an app mode instead
                if let appMode = lastAutoAppMode {
                    try await activateMode(appMode)
                    return true
                }
            }
        } else {
            // Non-auto mode sets manual override
            isManualModeOverride = true
        }

        try await activateMode(targetMode)
        return true
    }
}
