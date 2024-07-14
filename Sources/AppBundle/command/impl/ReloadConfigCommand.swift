import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        var stdout = ""
        let isOk = reloadConfig(args: args, stdout: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
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
                activateMode(activeMode)
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
