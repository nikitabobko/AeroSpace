public enum CardinalDirection: String, CaseIterable, Equatable, Sendable {
    case left, down, up, right
}

public extension CardinalDirection {
    var orientation: Orientation { self == .up || self == .down ? .v : .h }
    var isPositive: Bool { self == .down || self == .right }
    var opposite: CardinalDirection {
        return switch self {
            case .left: .right
            case .down: .up
            case .up: .down
            case .right: .left
        }
    }
    var focusOffset: Int { isPositive ? 1 : -1 }
    var insertionOffset: Int { isPositive ? 1 : 0 }
}
