import BasicContainers
import Common
import Foundation

actor AwaitableOneTimeBroadcastLatch {
    private var done = false
    private var awaiters = UniqueDictionary<UniqueToken, Nullable<any StrictContinuation<(), any Error> & ~Copyable>>()

    func await(_ cm: CancellationMode) async throws {
        try checkCancellation(cm)
        if done { return }

        let id = UniqueToken()
        try await withTaskCancellationHandler {
            try await withStrictContinuation(of: Void.self, throwing: (any Error).self) { cont in
                switch awaiters.removeValue(forKey: id) {
                    case .null: cont.resume(throwing: CancellationError())
                    case .just: die()
                    case nil where done: cont.resume()
                    case nil: check(awaiters.insertValue(.just(cont), forKey: id) == nil)
                }
            }
        } onCancel: {
            if cm == .cancellable {
                Task.startUnstructured { await self.cancel(id: id) }
            }
        }
    }

    private func cancel(id: UniqueToken) {
        switch awaiters.removeValue(forKey: id) {
            case .just(let cont): cont.resume(throwing: CancellationError())
            case .null: die()
            case nil where !done:
                // Indicate to 'await' that the client should be cancelled right away when it suspends
                awaiters.insertValue(.null, forKey: id)
            case nil: break
        }
    }

    func signalToAll() {
        done = true
        let keys: [UniqueToken] = awaiters.copiedOutKeys
        for id in keys {
            switch awaiters.removeValue(forKey: id) {
                case .just(let cont): cont.resume()
                case .null: break
                case nil: break
            }
        }
    }
}
