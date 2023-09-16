enum Direction: String {
    case left, down, up, right
}

extension Direction {
    var orientation: Orientation { self == .up || self == .down ? .V : .H }
    var isPositive: Bool { self == .down || self == .right }
    var opposite: Direction {
        switch self {
        case .left:
            return .right
        case .down:
            return .up
        case .up:
            return .down
        case .right:
            return .left
        }
    }
}
