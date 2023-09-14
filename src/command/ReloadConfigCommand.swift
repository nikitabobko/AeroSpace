struct ReloadConfigCommand: Command {
    func run() {
        reloadConfig()
        refresh()
    }
}
