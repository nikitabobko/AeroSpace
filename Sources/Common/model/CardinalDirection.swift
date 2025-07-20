public enum CardinalDirection: String, CaseIterable, Equatable, Sendable {
    case left, down, up, right

    public var orientation: Orientation { self == .up || self == .down ? .v : .h }
    public var isPositive: Bool { self == .down || self == .right }
    public var opposite: CardinalDirection {
        return switch self {
            case .left: .right
            case .down: .up
            case .up: .down
            case .right: .left
        }
    }
    public var focusOffset: Int { isPositive ? 1 : -1 }
    public var insertionOffset: Int { isPositive ? 1 : 0 }
}
