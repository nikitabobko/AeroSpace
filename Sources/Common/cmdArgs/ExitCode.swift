public protocol ExitCode: RawRepresentable<Int32>, AeroAny, Sendable {
    static var fail: Self { get }
}

extension ExitCode {
    public static func fail(_ _: IoSideEffect) -> Self { .fail }
}

public let EXIT_CODE_ZERO: Int32 = 0
public let EXIT_CODE_TWO: Int32 = 2

public struct Int32ExitCode: ExitCode, Equatable {
    public var rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public static let fail = Int32ExitCode(rawValue: EXIT_CODE_TWO)
}

public enum BinaryExitCode: Int32, ExitCode {
    case succ = 0
    case fail = 2
    public static func from(bool: Bool) -> Self { bool ? .succ : .fail }

    public static func succ(_ _: IoSideEffect) -> Self { .succ }

    public func and(_ other: @autoclosure () -> Self) -> Self {
        switch rawValue {
            case EXIT_CODE_ZERO: other()
            default: self
        }
    }

    // periphery:ignore
    public func or(_ other: @autoclosure () -> Self) -> Self {
        switch rawValue {
            case EXIT_CODE_ZERO: self
            default: other()
        }
    }
}

public enum ConditionalExitCode: Int32, ExitCode {
    case _true = 0
    case _false = 1
    case fail = 2
}

public enum IoSideEffect {
    case instance
}
