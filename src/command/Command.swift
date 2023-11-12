protocol Command: AeroAny {
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
        check(Thread.current.isMainThread)
        await [self].run()
    }
}

extension [Command] {
    @MainActor
    func run() async {
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : ((singleOrNil() as? EnableCommand)?.lets { [$0] } ?? [])
        refresh(layout: false)
        for (index, command) in commands.withIndex {
            await command.runWithoutLayout()
            if index != commands.indices.last {
                refresh(layout: false)
            }
        }
        refresh()
    }
}
