protocol Copyable {}

extension Copyable {
    func copy<T>(_ key: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var copy = self
        copy[keyPath: key] = value
        return copy
    }
}
