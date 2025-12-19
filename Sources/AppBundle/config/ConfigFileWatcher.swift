import Common
import Foundation

final class ConfigFileWatcher {
    private let source: DispatchSourceFileSystemObject
    private let fd: Int32

    init?(url: URL, onChange: @escaping () -> Void) {
        let resolvedUrl = url.resolvingSymlinksInPath()
        let fd = open(resolvedUrl.path, O_EVTONLY)
        if fd < 0 {
            return nil
        }
        self.fd = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: .main,
        )
        self.source = source

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.activate()
    }

    func cancel() {
        source.cancel()
    }

    deinit {
        source.cancel()
    }
}

@MainActor private var currentWatcher: ConfigFileWatcher?
@MainActor private var debounceTask: Task<Void, Never>?

private let debounceDelay: Duration = .milliseconds(200)

@MainActor func syncConfigFileWatcher() {
    currentWatcher?.cancel()
    currentWatcher = nil

    guard config.autoReloadConfig else { return }

    currentWatcher = ConfigFileWatcher(url: configUrl) {
        Task { @MainActor in
            scheduleConfigReload()
        }
    }
}

@MainActor private func scheduleConfigReload() {
    debounceTask?.cancel()

    debounceTask = Task {
        try? await Task.sleep(for: debounceDelay)
        guard !Task.isCancelled else { return }

        if let token: RunSessionGuard = .isServerEnabled {
            try? await runLightSession(.configAutoReload, token) {
                _ = try await reloadConfig()
            }
        }
    }
}
