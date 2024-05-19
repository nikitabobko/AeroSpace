import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var stdout = ""
        let isOk = reloadConfig(args: args, stdout: &stdout)
        state.stdout.append(stdout)
        return isOk
    }
}

func reloadConfig(forceConfigUrl: URL? = nil) -> Bool {
    var devNull = ""
    return reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

func reloadConfig(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
    stdout: inout String
) -> Bool {
    switch readConfig(forceConfigUrl: forceConfigUrl) {
        case .success(let (parsedConfig, url)):
            if !args.dryRun {
                resetHotKeys()
                config = parsedConfig
                configUrl = url
                activateMode(mainModeId)
                syncStartAtLogin()
            }
            return true
        case .failure(let msg):
            stdout.append(msg)
            if !args.noGui {
                showMessageInGui(
                    filenameIfConsoleApp: nil,
                    title: "AeroSpace Config Error",
                    message: msg
                )
            }
            return false
    }
}
