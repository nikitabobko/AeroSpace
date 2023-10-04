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
            config.mainMode.activate()
            refresh()
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
            ForEach(Workspace.all) { workspace in
                Button {
                    Task { await WorkspaceCommand(workspaceName: workspace.name).run() }
                } label: {
                    Toggle(isOn: workspace.name == viewModel.focusedWorkspaceTrayText
                        ? Binding(get: { true }, set: { _, _ in })
                        : Binding(get: { false }, set: { _, _ in })) {
                        let monitor = (workspace.assignedMonitor?.name).flatMap { " - \($0)" } ?? ""
                        Text(workspace.name + monitor).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
            Button("Reload config") {
            } // todo
            Button("Quit \(Bundle.appName)") {
                terminateApp()
            }
                .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.focusedWorkspaceTrayText)
        }
    }
}
