struct CompositeCommand: Command {
    let subCommands: [Command]

    func runWithoutLayout() async {
        check(Thread.current.isMainThread)
        for command in subCommands {
            await command.runWithoutLayout()
            refresh(layout: false)
        }
    }
}
