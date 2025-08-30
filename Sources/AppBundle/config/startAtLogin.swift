import AppKit
import Common
import ServiceManagement

@MainActor
func syncStartAtLogin() {
    cleanupPlistFromPrevVersions()
    let service = SMAppService.mainApp
    if config.startAtLogin {
        if isDebug {
            print("'start-at-login = true' has no effect in debug builds")
        } else {
            _ = try? service.register()
        }
    } else {
        _ = try? service.unregister()
    }
}

private func cleanupPlistFromPrevVersions() { // todo Drop after a couple of versions
    let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appending(component: "Library/LaunchAgents/")
    Result { try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true) }.getOrDie()
    let url: URL = launchAgentsDir.appending(path: "bobko.aerospace.plist")
    try? FileManager.default.removeItem(at: url)
}
