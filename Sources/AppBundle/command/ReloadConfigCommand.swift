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

func reloadConfig() -> Bool {
    var devNull = ""
    return reloadConfig(stdout: &devNull)
}

func loadConfig(_ newConfig: Config) {
    resetHotKeys()
    config = newConfig
    activateMode(mainModeId)
    syncStartAtLogin()
}

func reloadConfig(args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(), stdout: inout String) -> Bool {
    switch readConfig() {
        case .success(let parsedConfig):
            if !args.dryRun {
                loadConfig(parsedConfig)
            }
            return true
        case .failure(let msg):
            stdout.append(msg)
            if !args.noGui {
                showMessageInGui(filename: "config-error.txt", message: msg)
            }
            return false
    }
}
