import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        var stdout = ""
        let isOk = try await reloadConfig(args: args, stdout: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
        return .from(bool: isOk)
    }
}

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    stdout: inout String,
) async throws -> Bool {
    let result: Bool
    switch readConfig(forceConfigUrl: forceConfigUrl) {
        case .success(let (parsedConfig, url)):
            if !args.dryRun {
                resetHotKeys()
                config = parsedConfig
                configUrl = url
                // Apply the auto-raise config before activateMode so a
                // throw from activateMode doesn't leave auto-raise lagging
                // behind the global `config`. Other post-assignment work
                // (syncStartAtLogin, MessageModel clear) is still skipped
                // on throw — that's a broader ordering story for another
                // change.
                AutoRaiseController.reload(config: config.autoRaise)
                try await activateMode(activeMode)
                syncStartAtLogin()
                MessageModel.shared.message = nil
            }
            result = true
        case .failure(let msg):
            stdout.append(msg)
            if !args.noGui {
                Task { @MainActor in
                    MessageModel.shared.message = Message(description: "AeroSpace Config Error", body: msg)
                }
            }
            result = false
    }
    if !args.dryRun {
        syncConfigFileWatcher()
    }
    return result
}
