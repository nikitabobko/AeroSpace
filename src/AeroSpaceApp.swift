import HotKey
import SwiftUI

let settings = [
    Setting(name: "W: 1", hotkey: .one, modifiers: [.option]),
    Setting(name: "W: 2", hotkey: .two, modifiers: [.option]),
    Setting(name: "W: 3", hotkey: .three, modifiers: [.option]),
]

struct Setting {
    let name: String
    let hotkey: Key
    let modifiers: NSEvent.ModifierFlags
}

//osascript -e 'tell app "Terminal"
//activate
//do script "tail -f ~/log/0.txt"
//end tell'

@main
struct AeroSpaceApp: App {
    var hotKeys: [HotKey] = [] // Keep hotkeys in memory
    @StateObject var viewModel = TrayModel.shared

    init() {
        if NSClassFromString("XCTestCase") == nil { // Prevent SwiftUI app loading during unit testing
            reloadConfig()

            checkAccessibilityPermissions()
            GlobalObserver.initObserver()
            config.mainMode.activate()
            refresh()
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
                NSApplication.shared.terminate(nil)
            }
                .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.focusedWorkspaceTrayText)
        }
    }
}
