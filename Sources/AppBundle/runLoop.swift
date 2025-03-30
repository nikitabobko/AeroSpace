import Common
import Foundation

extension Thread {
    @discardableResult
    func runInLoopAsync(
        job: RunLoopJob = RunLoopJob(),
        autoCheckCancelled: Bool = true,
        _ body: @Sendable @escaping (RunLoopJob) -> ()
    ) -> RunLoopJob {
        let action = RunLoopAction(job: job, autoCheckCancelled: autoCheckCancelled, body)
        // Alternative: CFRunLoopPerformBlock + CFRunLoopWakeUp
        action.perform(#selector(action.action), on: self, with: nil, waitUntilDone: false)
        return job
    }

    @MainActor // todo swift is stupid
    func runInLoop<T>(_ body: @Sendable @escaping (RunLoopJob) throws -> T) async throws -> T { // todo try to convert to typed throws
        try checkCancellation()
        let job = RunLoopJob()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                // It's unsafe to implicitly cancel because cont.resume should be invoked exactly once
                self.runInLoopAsync(job: job, autoCheckCancelled: false) { job in
                    if job.isCancelled {
                        cont.resume(throwing: CancellationError())
                    } else {
                        do {
                            cont.resume(returning: try body(job))
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                }
            }
        } onCancel: {
            job.cancel()
        }
    }
}

final class RunLoopAction: NSObject {
    private let _action: (RunLoopJob) -> ()
    let job: RunLoopJob
    private let autoCheckCancelled: Bool
    init(job: RunLoopJob, autoCheckCancelled: Bool, _ action: @escaping @Sendable (RunLoopJob) -> ()) {
        self.job = job
        self.autoCheckCancelled = autoCheckCancelled
        _action = action
    }
    @objc func action() {
        if autoCheckCancelled && job.isCancelled { return }
        _action(job)
    }
}

final class RunLoopJob: Sendable, AeroAny {
    private let cancellationLatch = OneTimeLatch()
    var isCancelled: Bool { cancellationLatch.isTriggered }
    func cancel() { cancellationLatch.trigger() }

    static let cancelled: RunLoopJob = RunLoopJob().also { $0.cancel() }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
}
