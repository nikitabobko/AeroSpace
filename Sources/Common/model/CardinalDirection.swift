public enum CardinalDirection: String, CaseIterable, Equatable {
    case left, down, up, right
}

public extension CardinalDirection {
    var orientation: Orientation { self == .up || self == .down ? .v : .h }
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
    var focusOffset: Int { isPositive ? 1 : -1 }
    var insertionOffset: Int { isPositive ? 1 : 0 }
}
