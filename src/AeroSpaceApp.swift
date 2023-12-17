import HotKey
import SwiftUI
import Common

@main
struct AeroSpaceApp: App {
    @StateObject var viewModel = TrayMenuModel.shared

    init() {
        initAeroSpaceApp()
        if !isUnitTest { // Prevent SwiftUI app loading during unit testing
            if isDebug {
                sendCommandToReleaseServer(command: "enable off")
                interceptTermination(SIGINT)
                interceptTermination(SIGKILL)
            }
            let startedAtLogin = CommandLine.arguments.getOrNil(atIndex: 1) == "--started-at-login"
            reloadConfig()
            if startedAtLogin && !config.startAtLogin {
                terminateApp()
            }

            checkAccessibilityPermissions()
            startServer()
            GlobalObserver.initObserver()
            refreshAndLayout(startup: true)
            refreshSession {
                var focused = CommandSubject.focused
                if startedAtLogin {
                    _ = config.afterLoginCommand.run(&focused)
                }
                _ = config.afterStartupCommand.run(&focused)
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
                    refreshSession {
                        WorkspaceCommand(args: WorkspaceCmdArgs(
                            target: .workspaceName(name: workspace.name, autoBackAndForth: false)
                        )).runOnFocusedSubject()
                    }
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
                refreshSession {
                    EnableCommand(args: EnableCmdArgs(targetState: .toggle)).runOnFocusedSubject()
                }
            }
                .keyboardShortcut("E", modifiers: .command)
            Button("Reload config") {
                refreshSession { ReloadConfigCommand().runOnFocusedSubject() }
            }
                .keyboardShortcut("R", modifiers: .command)
            Button("Quit \(Bundle.appName)") {
                terminationHandler.beforeTermination()
                terminateApp()
            }
                .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.isEnabled ? viewModel.trayText : "⏸️")
        }
    }
}
