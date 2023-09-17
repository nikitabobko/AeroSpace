struct ReloadConfigCommand: Command {
    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        reloadConfig()
    }
}
