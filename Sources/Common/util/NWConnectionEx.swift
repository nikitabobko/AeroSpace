import Network
import Foundation

extension NWConnection {
    public func writeAtomic(_ msg: Codable, _ encoder: JSONEncoder = JSONEncoder()) async -> ((), error: NWError?) {
        let payload = Result { try encoder.encode(msg) }.getOrDie()
        var data = unsafe withUnsafeBytes(of: UInt32(payload.count)) { unsafe Data($0) }
        check(data.count == 4)
        data.append(payload)
        return await withCheckedContinuation { cont in
            send(content: data, completion: .contentProcessed { error in
                switch error {
                    case let error?: cont.resume(returning: ((), error))
                    case nil: cont.resume(returning: ((), nil))
                }
            })
        }
    }

    public func startBlocking() async -> ((), error: NWError?) {
        await withCheckedContinuation { cont in
            let isDone = IsDone()
            stateUpdateHandler = { state in
                Task {
                    let error: NWError?
                    switch state {
                        case .cancelled, .preparing, .setup: return
                        case .ready: error = nil
                        case .failed(let e), .waiting(let e): error = e
                        @unknown default: die("Unknown NWConnection.State: \(state)")
                    }
                    // Make sure to resume continuation only once
                    if await isDone.markAsDone().wasAlreadyDone {
                        return
                    }
                    self.stateUpdateHandler = nil
                    cont.resume(returning: ((), error))
                }
            }
            start(queue: .global())
        }
    }

    private func read(bytes size: Int) async -> Result<Data, NWError> {
        var data = Data(capacity: size)
        while data.count < size {
            let remaining = size - data.count
            let chunk: Result<Data, NWError> = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: remaining, maximumLength: remaining) { data, context, isComplete, error in
                    switch error {
                        case let error?: cont.resume(returning: .failure(error))
                        case nil: cont.resume(returning: .success(data ?? Data()))
                    }
                }
            }
            switch chunk {
                case .success(let chunk): data.append(chunk)
                case .failure: return chunk
            }
        }
        return .success(data)
    }

    public func readTillError() async {
        while true {
            let isError = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: 1, maximumLength: Int.max) { data, context, isComplete, error in
                    cont.resume(returning: error != nil || data == nil || data?.count == 0)
                }
            }
            if isError { return }
        }
    }

    public func readNonAtomic() async -> Result<Data, NWError> {
        switch await read(bytes: 4) {
            case .success(let header):
                let count = unsafe header.withUnsafeBytes { unsafe $0.load(as: UInt32.self) }
                return await read(bytes: Int(count))
            case .failure(let e):
                return .failure(e)
        }
    }
}

private actor IsDone {
    private var isDone: Bool = false

    func markAsDone() -> (wasAlreadyDone: Bool, ()) {
        let old = isDone
        isDone = true
        return (old, ())
    }
}
