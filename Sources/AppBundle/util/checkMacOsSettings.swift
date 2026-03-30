import AppKit
import Foundation

@MainActor
func checkMacOsSettings() {
    checkAutoSwoosh()
}

private func checkAutoSwoosh() {
    guard let dockDefaults = UserDefaults(suiteName: "com.apple.dock") else { return }
    // workspaces-auto-swoosh defaults to true when unset
    let autoSwoosh = dockDefaults.object(forKey: "workspaces-auto-swoosh") as? Bool ?? true
    if autoSwoosh {
        let alert = NSAlert()
        alert.messageText = "Recommended macOS Setting"
        alert.informativeText = """
            The macOS setting "When switching to an application, switch to a Space \
            that has open windows for the application" is currently enabled. \
            This interferes with Airlock workspace management.

            Would you like Airlock to disable it for you? \
            (This requires restarting the Dock.)
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Disable It")
        alert.addButton(withTitle: "Remind Me Later")
        alert.addButton(withTitle: "Ignore")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            disableAutoSwoosh()
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(true, forKey: "airlock-ignore-auto-swoosh")
        default:
            break
        }
    }
}

private func disableAutoSwoosh() {
    let task = Process()
    task.executableURL = URL(filePath: "/usr/bin/defaults")
    task.arguments = ["write", "com.apple.dock", "workspaces-auto-swoosh", "-bool", "NO"]
    try? task.run()
    task.waitUntilExit()

    let killDock = Process()
    killDock.executableURL = URL(filePath: "/usr/bin/killall")
    killDock.arguments = ["Dock"]
    try? killDock.run()
    killDock.waitUntilExit()
}
