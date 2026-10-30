public protocol Withable: ~Copyable {}

extension Withable {
    public consuming func with<T>(_ key: WritableKeyPath<Self, T>, _ value: T) -> Self {
        self[keyPath: key] = value
        return self
    }
}
