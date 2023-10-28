struct CompositeCommand: Command {
    let subCommands: [Command]

    func runWithoutRefresh() async {
        check(Thread.current.isMainThread)
        for command in subCommands {
            await command.runWithoutRefresh()
            normalizeContainers()
        }
    }
}
