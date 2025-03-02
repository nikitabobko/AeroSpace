// "Happy path" Optional
public enum Lateinit<T> {
    case initialized(T)
    case uninitialized

    public var val: T {
        switch self {
            case .initialized(let value): return value
            case .uninitialized: error("Property is not initialized")
        }
    }

    public var isInitialized: Bool {
        return switch self {
            case .initialized: true
            case .uninitialized: false
        }
    }
}

extension Lateinit: Equatable where T: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isInitialized && rhs.isInitialized && lhs.val == rhs.val ||
            lhs.isInitialized == rhs.isInitialized
    }
}

extension Lateinit: Sendable where T: Sendable {}
