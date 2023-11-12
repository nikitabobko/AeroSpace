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
        check(Thread.current.isMainThread)
        await [self].run()
    }
}

extension [Command] {
    @MainActor
    func run() async {
        check(Thread.current.isMainThread)
        if !TrayMenuModel.shared.isEnabled {
            return
        }
        refresh(layout: false)
        for (index, command) in self.withIndex {
            await command.runWithoutLayout()
            if index != indices.last {
                refresh(layout: false)
            }
        }
        refresh()
    }
}
