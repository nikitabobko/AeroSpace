enum CardinalDirection: String {
    case left, down, up, right
}

extension CardinalDirection {
    var orientation: Orientation { self == .up || self == .down ? .V : .H }
    var isPositive: Bool { self == .down || self == .right }
    var opposite: CardinalDirection {
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
