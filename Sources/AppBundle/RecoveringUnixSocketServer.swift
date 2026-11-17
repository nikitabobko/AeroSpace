import Common
import Foundation
import Network

@MainActor final class RecoveringUnixSocketServer {
    private let path: String
    private let onConnection: @Sendable (NWConnection) -> Void
    private var listener: NWListener?
    private var watcher: DispatchSourceFileSystemObject?
    private var socketIdentity: [FileAttributeKey: NSNumber]?
    private var retry: Task<Void, Never>?
    private var running = false

    init(path: String, onConnection: @escaping @Sendable (NWConnection) -> Void) {
        self.path = path
        self.onConnection = onConnection
    }

    func start() throws {
        guard !running else { return }
        guard listener == nil else { throw CocoaError(.fileWriteFileExists) }
        // Only startup removes the socket left by a previous process. Recovery
        // below removes a pathname only if its inode still belongs to us.
        try? FileManager.default.removeItem(atPath: path)
        running = true
        do { try bind() } catch {
            running = false
            throw error
        }
    }

    func stop() {
        running = false
        retry?.cancel()
        retry = nil
        cancelWatcher()
        listener?.cancel()
    }

    private func identity() -> [FileAttributeKey: NSNumber]? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              attrs[.type] as? FileAttributeType == .typeSocket,
              let inode = attrs[.systemFileNumber] as? NSNumber,
              let device = attrs[.systemNumber] as? NSNumber else { return nil }
        return [.systemFileNumber: inode, .systemNumber: device]
    }

    private func bind() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .unix(path: path)
        let candidate = try NWListener(using: params)
        listener = candidate
        candidate.newConnectionHandler = onConnection
        candidate.stateUpdateHandler = { [weak self, weak candidate] state in
            Task.startUnstructured { @MainActor in
                guard let self, let candidate, self.listener === candidate else { return }
                switch state {
                    case .ready:
                        self.socketIdentity = self.identity()
                        self.watchSocket()
                    case .failed(let error):
                        NSLog("AeroSpace socket listener failed: %@", String(describing: error))
                        self.cancelWatcher()
                        candidate.cancel()
                    case .cancelled:
                        self.cancelWatcher()
                        self.listener = nil
                        if let owned = self.socketIdentity, self.identity() == owned {
                            try? FileManager.default.removeItem(atPath: self.path)
                        }
                        self.socketIdentity = nil
                        if self.running { self.scheduleBind() }
                    default: break
                }
            }
        }
        candidate.start(queue: .global())
    }

    private func cancelWatcher() {
        watcher?.cancel()
        watcher = nil
    }

    private func watchSocket() {
        cancelWatcher()
        guard running else { listener?.cancel(); return }
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let fd = unsafe open(directory, O_EVTONLY)
        guard fd >= 0 else {
            // A parent directory can disappear while the endpoint is binding.
            listener?.cancel()
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: .main,
        )
        source.setEventHandler { [weak self, weak source] in
            MainActor.checkIsolated {
                guard let self, let source, self.watcher === source,
                      self.identity() != self.socketIdentity else { return }
                NSLog("AeroSpace socket pathname disappeared; rebinding listener")
                self.cancelWatcher()
                self.listener?.cancel()
            }
        }
        source.setCancelHandler { close(fd) }
        watcher = source
        source.activate()
        // Darwin cannot open a socket with O_EVTONLY. Watch its directory,
        // then compare inode identity; unrelated directory writes do nothing.
        // Also cover unlink between the ready callback and watcher activation.
        if socketIdentity == nil || identity() != socketIdentity { listener?.cancel() }
    }

    private func scheduleBind() {
        retry?.cancel()
        retry = Task.startUnstructured { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            guard let self, self.running, self.listener == nil else { return }
            // Do not unlink a replacement endpoint or unrelated file. Wait until
            // the pathname is available rather than take another owner's socket.
            guard !FileManager.default.fileExists(atPath: self.path) else {
                self.scheduleBind()
                return
            }
            do { try self.bind() } catch {
                NSLog("AeroSpace socket rebind failed: %@", String(describing: error))
                self.scheduleBind()
            }
        }
    }
}
