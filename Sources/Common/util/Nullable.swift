/// Like Swift's built-in Optional but avoids implicit nil coercions
public enum Nullable<T: ~Copyable>: ~Copyable {
    case just(T)
    case null
}

extension Nullable: Copyable where T: Copyable {}
