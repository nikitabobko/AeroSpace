/// Like Swift's built-in Optional but avoids implicit nil coercions
public enum Nullable<T> {
    case some(T)
    case null

    public var valueOrNil: T? {
        switch self {
            case .some(let value): value
            case .null: nil
        }
    }

    public var isNull: Bool { valueOrNil == nil }
}
