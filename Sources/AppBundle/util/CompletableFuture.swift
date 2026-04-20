import Dispatch

final class CompletableFuture<T>: Sendable {
    nonisolated(unsafe) private var value: T?
    private let semaphore = DispatchSemaphore(value: 0)

    func complete(_ t: T) {
        unsafe value = t
        semaphore.signal()
    }

    func blockingGet() -> T {
        semaphore.wait()
        return unsafe value.orDie("semaphore should have been signaled")
    }
}
