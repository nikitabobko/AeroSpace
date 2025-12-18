import Common
import Foundation

final class ConfigFileWatcher: @unchecked Sendable {
    @MainActor static let shared = ConfigFileWatcher()

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var watchedUrl: URL?
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "aerospace.config-watcher", qos: .utility)

    private let debounceDelay: TimeInterval = 0.2

    private init() {}

    @MainActor
    func startWatching(url: URL) {
        let resolvedUrl = url.resolvingSymlinksInPath()

        queue.async { [self, resolvedUrl] in
            if self.watchedUrl == resolvedUrl && self.dispatchSource != nil {
                return
            }

            self.stopWatchingInternal()

            let fd = open(resolvedUrl.path, O_EVTONLY)
            if fd == -1 {
                return
            }

            self.watchedUrl = resolvedUrl
            self.createWatcher(fd: fd)
        }
    }

    @MainActor
    func stopWatching() {
        queue.async { [self] in
            self.stopWatchingInternal()
        }
    }

    private func stopWatchingInternal() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let source = dispatchSource {
            source.cancel()
            dispatchSource = nil
        }
        watchedUrl = nil
    }

    private func createWatcher(fd: Int32) {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: queue,
        )

        source.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            let flags = source.data
            self.handleFileEvent(flags: flags)
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                return
            }
            close(fd)
            if self.dispatchSource === source {
                self.dispatchSource = nil
            }
        }

        dispatchSource = source
        source.resume()
    }

    private func handleFileEvent(flags: DispatchSource.FileSystemEvent) {
        if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
            handleFileReplacement()
        } else if flags.contains(.write) {
            scheduleReload()
        }
    }

    private func handleFileReplacement() {
        guard let url = watchedUrl else { return }

        dispatchSource?.cancel()
        dispatchSource = nil

        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.watchedUrl == url else { return }

            let fd = open(url.path, O_EVTONLY)
            if fd == -1 {
                self.watchedUrl = nil
                return
            }

            self.createWatcher(fd: fd)
            self.triggerReload()
        }

        queue.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func scheduleReload() {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.triggerReload()
        }

        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    private func triggerReload() {
        Task { @MainActor in
            _ = try? await reloadConfig()
            scheduleRefreshSession(.configAutoReload)
        }
    }
}

@MainActor func syncConfigFileWatcher() {
    if config.autoReloadConfig {
        ConfigFileWatcher.shared.startWatching(url: configUrl)
    } else {
        ConfigFileWatcher.shared.stopWatching()
    }
}
