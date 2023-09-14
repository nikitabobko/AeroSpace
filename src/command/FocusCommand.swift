struct FocusCommand: Command {
    let direction: Direction

    enum Direction: String {
        case up, down, left, right

        case parent, child, floating, tiling, toggle_tiling_floating
    }

    func run() {
        // todo
    }
}
