import Network
import Foundation

extension NWConnection {
    public func writeAtomic(_ msg: Codable, _ encoder: JSONEncoder = JSONEncoder()) async -> ((), error: NWError?) {
        let payload = Result { try encoder.encode(msg) }.getOrDie()
        var data = unsafe withUnsafeBytes(of: UInt32(payload.count)) { pointer in unsafe Data.init(pointer) }
        check(data.count == 4)
        data.append(payload)
        return await withCheckedContinuation { cont in
            send(content: data, completion: .contentProcessed { error in
                cont.resume(returning: ((), error))
            })
        }
    }

    public func initConnection() async -> ((), error: InitConnectionError?) {
        let error1 = await withCheckedContinuation { cont in
            let isDone = IsDone()
            stateUpdateHandler = { state in
                Task.startUnstructured {
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
                    cont.resume(returning: error.map(InitConnectionError.nwError))
                }
            }
            start(queue: .global())
        }
        if error1 != nil { return ((), error1) }

        let error2 = await writeUInt32(SOCKET_PROTOCOL_VERSION).error
        if error2 != nil { return ((), error2.map(InitConnectionError.nwError)) }

        switch await self.readUInt32() {
            case .success(let serverVersion) where serverVersion != SOCKET_PROTOCOL_VERSION:
                let msg = """
                    Client SOCKET_PROTOCOL_VERSION: \(SOCKET_PROTOCOL_VERSION)
                    Server SOCKET_PROTOCOL_VERSION: \(serverVersion)

                    The client and server versions are incompatible. (Potential fix: restart AeroSpace)
                    """
                return ((), .customError(msg))
            case .success:
                return ((), nil)
            case .failure(let error):
                return ((), .nwError(error))
        }
    }

    public enum InitConnectionError: Sendable {
        case nwError(NWError)
        case customError(String)
    }

    private func read(bytes size: Int) async -> Result<Data, NWError> {
        var data = Data(capacity: size)
        while data.count < size {
            let remaining = size - data.count
            let chunk: Result<Data, NWError> = await withCheckedContinuation { cont in
                receive(minimumIncompleteLength: remaining, maximumLength: remaining) { data, context, isComplete, error in
                    cont.resume(returning: error.map(Result.failure) ?? Result.success(data ?? Data()))
                }
            }
            switch chunk {
                case .success(let chunk): data.append(chunk)
                case .failure: return chunk
            }
        }
        check(data.count == size)
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

    public func readUInt32() async -> Result<UInt32, NWError> {
        await read(bytes: 4).map { data in
            unsafe data.withUnsafeBytes { pointer in unsafe pointer.load(as: UInt32.self) }
        }
    }

    public func writeUInt32(_ int: UInt32) async -> ((), error: NWError?) {
        let data = unsafe withUnsafeBytes(of: int) { pointer in unsafe Data.init(pointer) }
        check(data.count == 4)
        return await withCheckedContinuation { cont in
            send(content: data, completion: .contentProcessed { error in cont.resume(returning: ((), error)) })
        }
    }

    public func readNonAtomic() async -> Result<Data, NWError> {
        switch await readUInt32() {
            case .success(let count):
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
