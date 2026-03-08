import Common
import Foundation

actor AwaitableOneTimeBroadcastLatch {
    private var done = false
    private var awaiters: [UniqueToken: Nullable<CheckedContinuation<(), any Error>>] = [:]

    func await() async throws {
        try checkCancellation()
        if done { return }

        let id = UniqueToken()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(), any Error>) in
                if let awaiter = awaiters.removeValue(forKey: id) {
                    check(awaiter.isNull)
                    cont.resume(throwing: CancellationError())
                } else if done {
                    cont.resume()
                } else {
                    awaiters[id] = .just(cont)
                }
            }
        } onCancel: {
            Task { await cancel(id: id) }
        }
    }

    private func cancel(id: UniqueToken) {
        if let awaiter = awaiters.removeValue(forKey: id) {
            awaiter.valueOrNil.orDie().resume(throwing: CancellationError())
        } else if !done {
            awaiters[id] = .null // Indicate to 'await' that the client should be cancelled right away when it suspends
        }
    }

    func signalToAll() {
        done = true
        for (_, awaiter) in awaiters {
            awaiter.valueOrNil?.resume()
        }
        awaiters = [:]
    }
}
