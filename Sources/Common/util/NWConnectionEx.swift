import Network
import Foundation

extension NWConnection {
    public func write(_ data: Data) async -> NWError? {
        await withCheckedContinuation { cont in
            send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(returning: error)
                } else {
                    cont.resume(returning: nil)
                }
            })
        }
    }

    public func startBlocking() async -> NWError? {
        await withCheckedContinuation { cont in
            stateUpdateHandler = { state in
                switch state {
                    case .cancelled, .preparing, .setup: break
                    case .ready:
                        self.stateUpdateHandler = nil
                        cont.resume(returning: nil)
                    case .failed(let error), .waiting(let error):
                        self.stateUpdateHandler = nil
                        cont.resume(returning: error)
                    @unknown default: break
                }
            }
            start(queue: .global())
        }
    }

    public func read() async -> Result<Data, NWError> {
        await withCheckedContinuation { cont in
            receive(minimumIncompleteLength: 0, maximumLength: Int.max) { data, context, isComplete, error in
                if let error {
                    cont.resume(returning: .failure(error))
                } else {
                    cont.resume(returning: .success(data ?? Data()))
                }
            }
        }
    }
}
