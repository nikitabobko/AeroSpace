import Common

struct ListExecEnvVarsCommand: Command {
    let args: ListExecEnvVarsCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        for (key, value) in config.execConfig.envVariables {
            state.stdout.append("\(key)=\(value)")
        }
        return true
    }
}
