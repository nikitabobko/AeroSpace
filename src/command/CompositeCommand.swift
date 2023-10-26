struct CompositeCommand: Command { // todo drop
    let subCommands: [Command]

    func runWithoutRefresh() async {
        check(Thread.current.isMainThread)
        for command in subCommands {
            await command.runWithoutRefresh()
        }
    }
}
