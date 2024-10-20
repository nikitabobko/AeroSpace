public enum CardinalDirection: String, CaseIterable, Equatable {
    case left, down, up, right, next, prev
}

public extension CardinalDirection {
    var orientation: Orientation { self == .up || self == .down ? .v : .h }
    var isPositive: Bool { self == .down || self == .right || self == .next}
    var opposite: CardinalDirection {
        return switch self {
            case .left: .right
            case .down: .up
            case .up: .down
            case .right: .left
            case .next: .next
            case .prev: .prev
        }
    }
    var focusOffset: Int { isPositive ? 1 : -1 }
    var insertionOffset: Int { isPositive ? 1 : 0 }
}
