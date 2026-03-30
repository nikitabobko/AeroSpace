public enum CardinalOrDfsDirection: Equatable, Sendable {
    case direction(CardinalDirection)
    case dfsRelative(DfsNextPrev)
    case appCycle(AppCycleDirection)
}

extension CardinalOrDfsDirection: CaseIterable {
    public static var allCases: [CardinalOrDfsDirection] {
        CardinalDirection.allCases.map { .direction($0) }
            + DfsNextPrev.allCases.map { .dfsRelative($0) }
            + AppCycleDirection.allCases.map { .appCycle($0) }
    }
}

extension CardinalOrDfsDirection: RawRepresentable {
    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        if let d = CardinalDirection(rawValue: rawValue) {
            self = .direction(d)
        } else if let np = DfsNextPrev(rawValue: rawValue) {
            self = .dfsRelative(np)
        } else if let ac = AppCycleDirection(rawValue: rawValue) {
            self = .appCycle(ac)
        } else {
            return nil
        }
    }

    public var rawValue: RawValue {
        return switch self {
            case .direction(let d): d.rawValue
            case .dfsRelative(let np): np.rawValue
            case .appCycle(let ac): ac.rawValue
        }
    }
}
