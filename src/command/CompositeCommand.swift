struct CompositeCommand: Command {
    let subCommands: [Command]

    func run() async {
        precondition(Thread.current.isMainThread)
        for command in subCommands {
            await command.run()
        }
    }
}
