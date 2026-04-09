public protocol ExitCode: RawRepresentable<Int32>, AeroAny, Sendable {
    static var fail: Self { get }
}

public let EXIT_CODE_ZERO: Int32 = 0

// Some big enough number which is not occupied by any other ExitCode
// The only exit code which is guaranteed to denote a error
public let EXIT_CODE_UNCLASSIFIED_ERROR: Int32 = 10

public struct Int32ExitCode: ExitCode, Equatable {
    public var rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public static let fail = Int32ExitCode(rawValue: EXIT_CODE_UNCLASSIFIED_ERROR)
}

public enum BinaryExitCode: Int32, ExitCode {
    case succ = 0
    case fail = 1
    public static func from(bool: Bool) -> Self { bool ? .succ : .fail }

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
