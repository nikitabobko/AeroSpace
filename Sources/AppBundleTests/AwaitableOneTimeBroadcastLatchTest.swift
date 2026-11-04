@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct AwaitableOneTimeBroadcastLatchTest {
    @Test func testAwaitAfterSignalReturnsImmediately() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        await latch.signalToAll()
        try await latch.await(.cancellable)
    }

    @Test func testAwaitOnFreshLatchSuspendsUntilSignal() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        let task = Task.startUnstructured { try await latch.await(.cancellable) }
        try await Task.sleep(for: .milliseconds(50))
        assertFalse(task.isCancelled)
        await latch.signalToAll()
        try await task.value
    }

    @Test func testSignalReleasesAllPendingAwaiters() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        let count = 20
        let tasks = (0 ..< count).map { _ in Task.startUnstructured { try await latch.await(.cancellable) } }
        try await Task.sleep(for: .milliseconds(50))
        await latch.signalToAll()
        for task in tasks { try await task.value }
    }

    @Test func testSignalIsIdempotent() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        await latch.signalToAll()
        await latch.signalToAll()
        await latch.signalToAll()
        try await latch.await(.cancellable)
        try await latch.await(.cancellable)
    }

    @Test func testSignalWithNoAwaiters() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        await latch.signalToAll()
        try await latch.await(.cancellable)
    }

    @Test func testCancellingPendingAwaiterThrows() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        let task = Task.startUnstructured { try await latch.await(.cancellable) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await assertThrowsCancellation(task)
    }

    @Test func testCancellingOneAwaiterDoesNotAffectOthers() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        let cancelled = Task.startUnstructured { try await latch.await(.cancellable) }
        let survivors = (0 ..< 5).map { _ in Task.startUnstructured { try await latch.await(.cancellable) } }
        try await Task.sleep(for: .milliseconds(50))
        cancelled.cancel()
        await assertThrowsCancellation(cancelled)
        await latch.signalToAll()
        for task in survivors { try await task.value }
    }

    @Test func testAwaitBailsWhenTaskIsAlreadyCancelled() async {
        let latch = AwaitableOneTimeBroadcastLatch()
        let task = Task.startUnstructured { () async throws in
            while !Task.isCancelled { await Task.yield() }
            try await latch.await(.cancellable)
        }
        task.cancel()
        await assertThrowsCancellation(task)
    }

    @Test func testSignalAfterCancellationStillReleasesRemainingAwaiters() async throws {
        let latch = AwaitableOneTimeBroadcastLatch()
        let cancelled = Task.startUnstructured { try await latch.await(.cancellable) }
        let lateJoiner = Task.startUnstructured { try await latch.await(.cancellable) }
        try await Task.sleep(for: .milliseconds(50))
        cancelled.cancel()
        await assertThrowsCancellation(cancelled)
        await latch.signalToAll()
        try await lateJoiner.value
        // New await arriving after the signal still returns immediately.
        try await latch.await(.cancellable)
    }

    private func assertThrowsCancellation<T: Sendable>(_ task: Task<T, any Error>, sourceLocation: SourceLocation = #_sourceLocation) async {
        do {
            _ = try await task.value
            failExpectedActual("CancellationError", "no error thrown", sourceLocation: sourceLocation)
        } catch is CancellationError {
            // expected
        } catch {
            failExpectedActual("CancellationError", error, sourceLocation: sourceLocation)
        }
    }
}
