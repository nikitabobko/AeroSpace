import Foundation

// https://forums.swift.org/t/using-async-call-in-boolean-expression/52943
// https://github.com/swiftlang/swift/issues/56869
// https://forums.swift.org/t/potential-false-positive-sending-risks-causing-data-races/78859
extension Bool {
    @inlinable
    public func andAsync(_ rhs: () async throws -> Bool) async rethrows -> Bool {
        if self {
            return try await rhs()
        }
        return false
    }

    @inlinable
    public func orAsync(_ rhs: () async throws -> Bool) async rethrows -> Bool {
        if self {
            return true
        }
        return try await rhs()
    }
}
