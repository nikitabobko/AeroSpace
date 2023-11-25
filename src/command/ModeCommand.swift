struct ModeCommand: Command {
    let idToActivate: String

    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        activateMode(idToActivate)
    }
}

var activeMode: String = mainModeId
func activateMode(_ modeToActivate: String) {
    for (_, mode) in config.modes {
        mode.deactivate()
    }
    for binding in config.modes[modeToActivate]?.bindings ?? [] {
        binding.activate()
    }
    activeMode = modeToActivate
}
