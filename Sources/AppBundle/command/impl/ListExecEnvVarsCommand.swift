import AppKit
import Common

struct ListExecEnvVarsCommand: Command {
    let args: ListExecEnvVarsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        for (key, value) in config.execConfig.envVariables {
            io.out("\(key)=\(value)")
        }
        return true
    }
}
