struct MoveThroughCommand: Command {
    let direction: Direction

    enum Direction {
        case left, down, up, right
    }

    func run() {

    }
}
