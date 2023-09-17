class CloseAllWindowsButCurrentCommand: Command {
    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        // todo
    }
}