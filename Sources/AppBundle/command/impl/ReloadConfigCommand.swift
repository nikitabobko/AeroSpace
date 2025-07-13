import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        var stdout = ""
        let isOk = reloadConfig(args: args, stdout: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
        return isOk
    }
}

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) -> Bool {
    var devNull = ""
    return reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

@MainActor func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    stdout: inout String,
) -> Bool {
    switch readConfig(forceConfigUrl: forceConfigUrl) {
        case .success(let (parsedConfig, url)):
            if !args.dryRun {
                resetHotKeys()
                config = parsedConfig
                configUrl = url
                activateMode(activeMode)
                syncStartAtLogin()
                MessageModel.shared.message = nil
            }
            return true
        case .failure(let msg):
            stdout.append(msg)
            if !args.noGui {
                Task { @MainActor in
                    MessageModel.shared.message = Message(description: "AeroSpace Config Error", body: msg)
                }
            }
            return false
    }
}
