struct ReloadConfigCommand: Command {
    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
