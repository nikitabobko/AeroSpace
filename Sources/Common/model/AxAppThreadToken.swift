import Foundation

@TaskLocal
public var axTaskLocalAppThreadToken: AxAppThreadToken? = nil

public struct AxAppThreadToken: Sendable, Equatable, CustomStringConvertible {
    public let pid: pid_t
    public let idForDebug: String

    public init(pid: pid_t, idForDebug: String) {
        self.pid = pid
        self.idForDebug = idForDebug
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.pid == rhs.pid }

    public func checkEquals(_ other: AxAppThreadToken?) {
        check(self == other, "\(self) != \(other.prettyDescription)")
    }

    public var description: String { idForDebug }
}
