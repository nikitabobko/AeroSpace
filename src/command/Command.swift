protocol Command {
    @MainActor
    func run() async
}
