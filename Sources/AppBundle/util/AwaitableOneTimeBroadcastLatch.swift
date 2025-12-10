import Common

actor AwaitableOneTimeBroadcastLatch {
    private var done = false
    private var awaiters: [Int: Nullable<CheckedContinuation<(), any Error>>] = [:]
    private var counter = Int.min

    func await() async throws {
        try checkCancellation()
        if done { return }

        let id = counter
        counter += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(), any Error>) in
                if let awaiter = awaiters.removeValue(forKey: id) {
                    check(awaiter.isNull)
                    cont.resume(throwing: CancellationError())
                } else if done {
                    cont.resume()
                } else {
                    awaiters[id] = .some(cont)
                }
            }
        } onCancel: {
            Task { await cancel(id: id) }
        }
    }

    private func cancel(id: Int) {
        if let awaiter = awaiters.removeValue(forKey: id) {
            awaiter.valueOrNil.orDie().resume(throwing: CancellationError())
        } else if !done {
            awaiters[id] = .null
        }
    }

    func signal() {
        done = true
        for (_, awaiter) in awaiters {
            awaiter.valueOrNil?.resume()
        }
        awaiters = [:]
    }
}
