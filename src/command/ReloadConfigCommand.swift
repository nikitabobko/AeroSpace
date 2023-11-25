struct ReloadConfigCommand: Command {
    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
