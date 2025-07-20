public protocol ConvenienceCopyable {}

extension ConvenienceCopyable {
    public consuming func copy<T>(_ key: WritableKeyPath<Self, T>, _ value: T) -> Self {
        self[keyPath: key] = value
        return self
    }
}
