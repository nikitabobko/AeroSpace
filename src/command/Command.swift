protocol Command {
    @MainActor
    func runWithoutLayout() async
}

protocol QueryCommand {
    @MainActor
    func run() -> String
}

extension Command {
    @MainActor
    func run() async {
        refresh(layout: false)
        await runWithoutLayout()
        refresh()
    }
}
