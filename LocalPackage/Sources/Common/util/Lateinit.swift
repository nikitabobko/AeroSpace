@propertyWrapper
public struct Lateinit<T> {
    private var _value: T?

    public init() {}

    public var wrappedValue: T {
        get { _value ?? errorT("Property is not initialized") }
        set { _value = newValue }
    }
}

extension Lateinit: Equatable where T: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool { lhs._value == rhs._value }
}
