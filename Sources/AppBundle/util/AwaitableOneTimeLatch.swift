import Common

actor AwaitableOneTimeLatch {
    private var done = false
    private var awaiters: [Int: Either<CheckedContinuation<(), any Error>, ()>] = [:]
    private var counter = Int.min

    func await() async throws {
        if done { return }

        let id = counter
        counter += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(), any Error>) in
                if let awaiter = awaiters.removeValue(forKey: id) {
                    check(awaiter.leftOrNil == nil)
                    cont.resume(throwing: CancellationError())
                } else {
                    awaiters[id] = .left(cont)
                }
            }
        } onCancel: {
            Task { await cancel(id: id) }
        }
    }

    private func cancel(id: Int) {
        if let awaiter = awaiters.removeValue(forKey: id) {
            awaiter.leftOrNil?.resume(throwing: CancellationError())
        } else {
            awaiters[id] = .right(())
        }
    }

    func signal() {
        done = true
        for (_, awaiter) in awaiters {
            awaiter.leftOrNil?.resume()
        }
        awaiters = [:]
    }
}
