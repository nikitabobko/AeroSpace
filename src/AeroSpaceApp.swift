import HotKey
import SwiftUI

@main
struct AeroSpaceApp: App {
    var hotKeys: [HotKey] = [] // Keep hotkeys in memory
    @StateObject var viewModel = TrayMenuModel.shared

    init() { // todo disable release server on debug server startup
        if !isUnitTest { // Prevent SwiftUI app loading during unit testing
            let startedAtLogin = CommandLine.arguments.getOrNil(atIndex: 1) == "--started-at-login"
            reloadConfig()
            if startedAtLogin && !config.startAtLogin {
                terminateApp()
            }

            checkAccessibilityPermissions()
            startServer()
            GlobalObserver.initObserver()
            refresh(startup: true)
            Task {
                if startedAtLogin {
                    await config.afterLoginCommand.run()
                }
                await config.afterStartupCommand.run()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            let shortIdentification = "\(Bundle.appName) v\(Bundle.appVersion) \(gitShortHash)"
            let identification      = "\(Bundle.appName) v\(Bundle.appVersion) \(gitHash)"
            Text(shortIdentification)
            Button("Copy to clipboard") { identification.copyToClipboard() }
                .keyboardShortcut("C", modifiers: .command)
            Divider()
            Text("Workspaces:")
            ForEach(Workspace.all) { (workspace: Workspace) in
                Button {
                    Task { await WorkspaceCommand(workspaceName: workspace.name).run() }
                } label: {
                    Toggle(isOn: workspace == Workspace.focused
                        ? Binding(get: { true }, set: { _, _ in })
                        : Binding(get: { false }, set: { _, _ in })) {
                        let monitor = workspace.isVisible || !workspace.isEffectivelyEmpty ? " - \(workspace.monitor.name)" : ""
                        Text(workspace.name + monitor).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
            Button(viewModel.isEnabled ? "Disable" : "Enable") {
                Task { await EnableCommand(targetState: .toggle).run() }
            }
                .keyboardShortcut("E", modifiers: .command)
            Button("Reload config") {
                Task { await ReloadConfigCommand().run() }
            }
                .keyboardShortcut("R", modifiers: .command)
            Button("Quit \(Bundle.appName)") {
                makeAllWindowsVisibleAndRestoreSize()
                terminateApp()
            }
                .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.isEnabled ? viewModel.trayText : "⏸️")
        }
    }
}
