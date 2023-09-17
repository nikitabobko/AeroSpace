protocol Command {
    @MainActor
    func runWithoutRefresh() async
}

extension Command {
    @MainActor
    func run() async  {
        refresh()
        await runWithoutRefresh()
        refresh(startSession: false)
    }
}
