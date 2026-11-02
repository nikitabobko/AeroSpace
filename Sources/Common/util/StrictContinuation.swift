// periphery:ignore:all - Those are utils that can become useful any moment

/// Backported non-Copyable Continuation (more performant and safer than other Continuations) from #macos27 to old macos versions
///
/// The API may be backported in the future:
/// - https://forums.swift.org/t/accepted-se-0528-non-copyable-continuation/86533/5
/// - https://github.com/swiftlang/swift/pull/93430
@safe public struct StrictContinuation<Success, Failure: Error>: ~Copyable, Sendable {
    private let raw: UnsafeContinuation<Success, Failure>

    fileprivate init(_ raw: UnsafeContinuation<Success, Failure>) { unsafe self.raw = raw }

    public consuming func resume(returning value: consuming sending Success) {
        unsafe raw.resume(returning: value)
        discard self
    }

    public consuming func resume(throwing error: consuming Failure) {
        unsafe raw.resume(throwing: error)
        discard self
    }

    deinit { die("StrictContinuation is leaked") }
}

public func withStrictContinuation<Success>(
    of: Success.Type = Success.self,
    _ body: (consuming StrictContinuation<Success, Never>) -> Void,
) async -> sending Success {
    await unsafe withUnsafeContinuation { cont in unsafe body(StrictContinuation(cont)) }
}

public func withStrictContinuation<Success, Failure: Error>(
    of: Success.Type = Success.self,
    throwing: Failure.Type,
    _ body: (consuming StrictContinuation<Success, Failure>) -> Void,
) async throws(Failure) -> sending Success {
    try await unsafe withUnsafeThrowingContinuation { cont in unsafe body(StrictContinuation(cont)) }
}

extension StrictContinuation where Success == () {
    public consuming func resume() { resume(returning: ()) }
}
