struct CompositeCommand: Command {
    let subCommands: [Command]

    func runWithoutRefresh() async {
        precondition(Thread.current.isMainThread)
        for command in subCommands {
            await command.runWithoutRefresh()
        }
    }
}
