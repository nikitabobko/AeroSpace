public struct NonCopyable<T>: ~Copyable {
    public var value: T
    public init(_ value: T) { self.value = value }
    /// Once you call this method, the value becomes inaccessible
    @discardableResult consuming public func consume() -> T { value }
}
