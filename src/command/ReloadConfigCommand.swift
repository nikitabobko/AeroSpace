struct ReloadConfigCommand: Command {
    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
