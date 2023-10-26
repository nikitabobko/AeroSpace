struct ReloadConfigCommand: Command {
    func runWithoutRefresh() {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
