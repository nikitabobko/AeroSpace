import Common
import Foundation

extension Thread {
    @discardableResult
    func runInLoopAsync(
        job: RunLoopJob = RunLoopJob(),
        autoCheckCancelled: Bool = true,
        _ body: @Sendable @escaping (RunLoopJob) -> (),
    ) -> RunLoopJob {
        let action = RunLoopAction(job: job, autoCheckCancelled: autoCheckCancelled, body)
        // Alternative: CFRunLoopPerformBlock + CFRunLoopWakeUp
        action.perform(#selector(action.action), on: self, with: nil, waitUntilDone: false)
        return job
    }

    func runInLoop<T>(_ body: @Sendable @escaping (RunLoopJob) throws -> T) async throws -> T { // todo try to convert to typed throws
        try checkCancellation()
        let job = RunLoopJob()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                // It's unsafe to implicitly cancel because cont.resume should be invoked exactly once
                self.runInLoopAsync(job: job, autoCheckCancelled: false) { job in
                    do {
                        try job.checkCancellation()
                        cont.resume(returning: try body(job))
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            job.cancel()
        }
    }
}

private final class RunLoopAction: NSObject, Sendable {
    private let _action: @Sendable (RunLoopJob) -> ()
    let job: RunLoopJob
    private let autoCheckCancelled: Bool
    private let _refreshSessionEvent: RefreshSessionEvent?
    init(job: RunLoopJob, autoCheckCancelled: Bool, _ action: @escaping @Sendable (RunLoopJob) -> ()) {
        self.job = job
        self.autoCheckCancelled = autoCheckCancelled
        _action = action
        _refreshSessionEvent = refreshSessionEvent
    }
    @objc func action() {
        if autoCheckCancelled && job.isCancelled { return }
        $refreshSessionEvent.withValue(_refreshSessionEvent) {
            _action(job)
        }
    }
}

final class RunLoopJob: Sendable, AeroAny {
    // Alternative 1. In macOS 15, it's possible to use `Atomic<Bool>` from `Synchronization` module
    // Alternative 2. https://github.com/apple/swift-atomics/tree/main but I don't want to add one more dependency just for
    //                AtomicBool
    private nonisolated(unsafe) var _isCancelled: Int32 = 0
    var isCancelled: Bool { _isCancelled == 1 }
    func cancel() {
        while !isCancelled {
            OSAtomicCompareAndSwapInt(0, 1, &_isCancelled)
        }
    }

    static let cancelled: RunLoopJob = RunLoopJob().also { $0.cancel() }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
}
