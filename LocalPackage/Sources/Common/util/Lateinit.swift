// "Happy path" Optional
public enum Lateinit<T> {
    case initialized(T)
    case uninitialized

    public var val: T {
        switch self {
        case .initialized(let value):
            return value
        case .uninitialized:
            error("Property is not initialized")
        }
    }

    public var isInitialized: Bool {
        switch self {
        case .initialized:
            return true
        case .uninitialized:
            return false
        }
    }
}

extension Lateinit: Equatable where T: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.isInitialized && rhs.isInitialized && lhs.val == rhs.val ||
            lhs.isInitialized == rhs.isInitialized
    }
}
