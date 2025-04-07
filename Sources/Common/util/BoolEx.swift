import Foundation

// https://forums.swift.org/t/using-async-call-in-boolean-expression/52943
// https://github.com/swiftlang/swift/issues/56869
// https://forums.swift.org/t/potential-false-positive-sending-risks-causing-data-races/78859
public extension Bool {
    @inlinable
    func andAsync(isolation: isolated (any Actor)? = #isolation, _ rhs: () async throws -> Bool) async rethrows -> Bool {
        if self {
            return try await rhs()
        }
        return false
    }

    @inlinable
    @MainActor
    func andAsyncMainActor(_ rhs: @MainActor @Sendable () async throws -> Bool) async rethrows -> Bool {
        if self {
            return try await rhs()
        }
        return false
    }

    @inlinable
    func orAsync(isolation: isolated (any Actor)? = #isolation, _ rhs: () async throws -> Bool) async rethrows -> Bool {
        if self {
            return true
        }
        return try await rhs()
    }

    @inlinable
    @MainActor
    func orAsyncMainActor(_ rhs: @MainActor @Sendable () async throws -> Bool) async rethrows -> Bool {
        if self {
            return true
        }
        return try await rhs()
    }
}
