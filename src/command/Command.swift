protocol Command {
    @MainActor
    func runWithoutLayout() async
}

extension Command {
    @MainActor
    func run() async  {
        refresh(layout: false)
        await runWithoutLayout()
        refresh()
    }
}
