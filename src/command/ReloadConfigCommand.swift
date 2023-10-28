struct ReloadConfigCommand: Command {
    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
