import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        var stdout = ""
        let isOk = try await reloadConfig(args: args, combinedErrorMsg: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
        return .from(bool: isOk)
    }
}

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, combinedErrorMsg: &devNull)
}

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    combinedErrorMsg: inout String,
) async throws -> Bool {
    let result = readConfig(forceConfigUrl: forceConfigUrl)
    if let msg = result.combinedErrorMsg {
        combinedErrorMsg.append(msg)
        if !args.noGui {
            Task.startUnstructured { @MainActor in
                MessageModel.shared.message = Message(description: "AeroSpace Config Diagnostics", body: msg)
            }
        }
    } else {
        MessageModel.shared.message = nil
    }
    if result.allowReloadConfig && !args.dryRun {
        resetHotKeys()
        config = result.config
        configUrl = result.configUrl
        try await activateMode(activeMode)
        syncStartAtLogin()
        syncConfigFileWatcher()
    }
    return result.combinedErrorMsg == nil
}
