import AppKit
import Common
import Foundation
import CoreServices

@MainActor
class ConfigFileWatcher {
    private var eventStream: FSEventStreamRef?
    private var watchedFileUrl: URL?
    private var lastModificationDate: Date?
    private var debounceTask: Task<Void, Never>?

    func startWatching(configUrl: URL) {
        stopWatching()

        guard config.autoReloadConfig else { return }

        guard configUrl != defaultConfigUrl else { return }

        watchedFileUrl = configUrl

        if let attrs = try? FileManager.default.attributesOfItem(atPath: configUrl.path),
           let modDate = attrs[.modificationDate] as? Date
        {
            lastModificationDate = modDate
        }

        let directoryPath = configUrl.deletingLastPathComponent().path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil,
        )

        let pathsToWatch = [directoryPath] as CFArray
        let callback: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>,
        ) in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<ConfigFileWatcher>.fromOpaque(info).takeUnretainedValue()

            // Filter events to only react to our specific file
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            guard let watchedPath = watcher.watchedFileUrl?.path else { return }

            for i in 0 ..< numEvents {
                let flags = eventFlags[i]
                let isFile = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)) != 0
                let isRelevant = (flags & FSEventStreamEventFlags(
                    kFSEventStreamEventFlagItemModified |
                        kFSEventStreamEventFlagItemRenamed |
                        kFSEventStreamEventFlagItemCreated |
                        kFSEventStreamEventFlagItemChangeOwner,
                )) != 0

                if isFile && isRelevant && paths[i] == watchedPath {
                    // Already on main queue
                    watcher.handleFileChange()
                    break
                }
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // latency in seconds, letting the system coalesce events
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents),
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)

        if !FSEventStreamStart(stream) {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return
        }

        eventStream = stream
    }

    func stopWatching() {
        debounceTask?.cancel()
        debounceTask = nil

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }

        watchedFileUrl = nil
        lastModificationDate = nil
    }

    private func handleFileChange() {
        guard let url = watchedFileUrl else {
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date
        else {
            return
        }

        guard modDate > (lastModificationDate ?? .distantPast) else {
            return
        }

        lastModificationDate = modDate

        debounceTask?.cancel()

        // Debounce the reload to handle atomic save sequences (write → rename → swap)
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Reload config within a session to ensure layout refresh happens
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try? await runSession(.autoReloadConfig, token) {
                _ = reloadConfig(forceConfigUrl: url)
            }
        }
    }
}

@MainActor private var _configFileWatcher: ConfigFileWatcher?

@MainActor
func startConfigFileWatcher() {
    if _configFileWatcher == nil {
        _configFileWatcher = ConfigFileWatcher()
    }
    _configFileWatcher?.startWatching(configUrl: configUrl)
}

@MainActor
func stopConfigFileWatcher() {
    _configFileWatcher?.stopWatching()
}
