struct ModeCommand: Command {
    let args: ModeCmdArgs

    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        activateMode(args.targetMode)
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
