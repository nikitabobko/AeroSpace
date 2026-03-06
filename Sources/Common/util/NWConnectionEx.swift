import Network
import Foundation

extension NWConnection {
    public func write(_ msg: Codable) async -> NWError? {
        let payload = Result { try JSONEncoder().encode(msg) }.getOrDie()
        var data = withUnsafeBytes(of: UInt32(payload.count)) { Data($0) }
        check(data.count == 4)
        data.append(payload)
        return await write(data)
    }

    private func write(_ data: Data) async -> NWError? {
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

    private func read(bytes size: UInt32) async -> Result<Data, NWError> {
        var data = Data(capacity: Int(size))
        while data.count < size {
            let chunk: Result<Data, NWError> = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: Int(size), maximumLength: Int(size)) { data, context, isComplete, error in
                    if let error {
                        cont.resume(returning: .failure(error))
                    } else {
                        cont.resume(returning: .success(data ?? Data()))
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

    public func read() async -> Result<Data, NWError> {
        switch await read(bytes: 4) {
            case .success(let header):
                let count = header.withUnsafeBytes { $0.load(as: UInt32.self) }
                return await read(bytes: count)
            case .failure(let e):
                return .failure(e)
        }
    }
}
