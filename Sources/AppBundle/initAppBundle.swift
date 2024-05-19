import Foundation
import Common

public func initAppBundle() {
    initTerminationHandler()
    isCli = false
    if isDebug {
        sendCommandToReleaseServer(args: ["enable", "off"])
        interceptTermination(SIGINT)
        interceptTermination(SIGKILL)
    }
    let startedAtLogin = CommandLine.arguments.getOrNil(atIndex: 1) == "--started-at-login"
    if !reloadConfig() {
        check(reloadConfig(forceConfigUrl: defaultConfigUrl))
    }
    if startedAtLogin && !config.startAtLogin {
        terminateApp()
    }

    checkAccessibilityPermissions()
    startServer()
    GlobalObserver.initObserver()
    refreshAndLayout(startup: true)
    refreshSession {
        let state: CommandMutableState = .focused
        if startedAtLogin {
            _ = config.afterLoginCommand.run(state)
        }
        _ = config.afterStartupCommand.run(state)
    }
}
