struct MoveThroughCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        // todo
    }
}
