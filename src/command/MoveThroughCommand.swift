struct MoveThroughCommand: Command {
    let direction: Direction

    enum Direction: String {
        case left, down, up, right
    }

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)

    }
}
