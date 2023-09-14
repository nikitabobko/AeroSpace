struct CompositeCommand: Command {
    let subCommands: [Command]

    func run() {
        for command in subCommands {
            command.run()
        }
    }
}
