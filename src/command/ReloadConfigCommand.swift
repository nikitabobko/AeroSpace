struct ReloadConfigCommand: Command {
    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        reloadConfig()
    }
}
