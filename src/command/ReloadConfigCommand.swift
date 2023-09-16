struct ReloadConfigCommand: Command {
    func run() async {
        precondition(Thread.current.isMainThread)
        reloadConfig()
        refresh()
    }
}
