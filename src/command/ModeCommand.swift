import Common

struct ModeCommand: Command {
    let info: CmdStaticInfo = ModeCmdArgs.info
    let args: ModeCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        activateMode(args.targetMode.val)
        return true
    }
}

var activeMode: String = mainModeId
func activateMode(_ targetMode: String) {
    for (_, mode) in config.modes {
        mode.deactivate()
    }
    for binding in config.modes[targetMode]?.bindings ?? [] {
        binding.activate()
    }
    activeMode = targetMode
}
