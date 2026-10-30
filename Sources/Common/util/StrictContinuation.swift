// periphery:ignore:all - Those are utils that can become useful any moment

/// Backported non-Copyable Continuation (more performant and safer than other Continuations) from #macos27 to old macos versions
public protocol StrictContinuation<Success, Failure>: ~Copyable, Sendable where Success: ~Copyable {
    associatedtype Success
    associatedtype Failure: Error
    consuming func resume(returning value: consuming sending Success)
    consuming func resume(throwing error: consuming Failure)
}

extension UnsafeContinuation: StrictContinuation {}

@available(macOS 27, *)
extension Continuation: StrictContinuation {}

public func withStrictContinuation<Success>(
    of: Success.Type = Success.self,
    _ body: (consuming any StrictContinuation<Success, Never> & ~Copyable) -> Void,
) async -> sending Success {
    if #available(macOS 27, *) {
        return await withContinuation { (cont: consuming Continuation<Success, Never>) in body(cont) }
    } else {
        return await unsafe withUnsafeContinuation { cont in unsafe body(cont) }
    }
}

public func withStrictContinuation<Success, Failure: Error>(
    of: Success.Type = Success.self,
    throwing: Failure.Type,
    _ body: (consuming any StrictContinuation<Success, Failure> & ~Copyable) -> Void,
) async throws(Failure) -> sending Success {
    if #available(macOS 27, *) {
        return try await withContinuation(of: of, throwing: Failure.self) { (cont: consuming Continuation<Success, Failure>) in body(cont) }
    } else {
        return try await unsafe withUnsafeThrowingContinuation { cont in unsafe body(cont) }
    }
}

extension StrictContinuation where Success == (), Self: ~Copyable {
    public consuming func resume() { resume(returning: ()) }
}
