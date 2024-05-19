public struct EquatableNoop<Value>: Equatable {
    public var value: Value
    public init(_ value: Value) { self.value = value }
    public static func == (lhs: EquatableNoop<Value>, rhs: EquatableNoop<Value>) -> Bool { true }
}
