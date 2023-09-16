struct MoveThroughCommand: Command {
    let direction: Direction

    enum Direction: String {
        case left, down, up, right
    }

    func run() async {
        precondition(Thread.current.isMainThread)

    }
}
