import HotKey
import SwiftUI

//osascript -e 'tell app "Terminal"
//activate
//do script "tail -f ~/log/0.txt"
//end tell'

@main
struct AeroSpaceApp: App {
    var hotKeys: [HotKey] = [] // Keep hotkeys in memory
    @StateObject var viewModel = TrayMenuModel.shared

    init() {
        if !isUnitTest { // Prevent SwiftUI app loading during unit testing
            let startedAtLogin = CommandLine.arguments.getOrNil(atIndex: 1) == "--started-at-login"
            reloadConfig()
            if startedAtLogin && !config.startAtLogin {
                terminateApp()
            }

            checkAccessibilityPermissions()
            GlobalObserver.initObserver()
            refresh(startup: true)
            if startedAtLogin {
                Task { await config.afterLoginCommand.run() }
            }
            Task { await config.afterStartupCommand.run() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Text("\(Bundle.appName) v\(Bundle.appVersion)")
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
            Button("Reload config") {
                Task { await ReloadConfigCommand().run() }
            }
            Button("Quit \(Bundle.appName)") {
                for app in apps { // Make all windows fullscreen before Quit
                    for window in app.windows {
                        let rect = window.workspace.monitor.visibleRect
                        window.setSize(CGSize(width: rect.width, height: rect.height))
                        window.setTopLeftCorner(rect.topLeftCorner)
                    }
                }
                terminateApp()
            }
                .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.trayText)
        }
    }
}
