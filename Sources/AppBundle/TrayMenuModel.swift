import AppKit
import Common
import SwiftUI

struct WorkspaceButton: Identifiable {
    let id = UUID()
    let button: Button<Toggle<Text>>
}

public class TrayMenuModel: ObservableObject {
    public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaceStatus: [WorkspaceButton] = []
}

func updateTrayText() {
    let sortedMonitors = sortedMonitors
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first?.lets { "[\($0)] " } ?? "") +
        sortedMonitors
        .map {
            ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
        }
        .joined(separator: " │ ")
    TrayMenuModel.shared.workspaceStatus = Workspace.all.map { (workspace: Workspace) in
        WorkspaceButton(button: Button {
            refreshSession { _ = workspace.focusWorkspace() }
        } label: {
            Toggle(isOn: workspace == focus.workspace
                ? Binding(get: { true }, set: { _, _ in })
                : Binding(get: { false }, set: { _, _ in }))
            {
                let monitor = workspace.isVisible || !workspace.isEffectivelyEmpty ? " - \(workspace.workspaceMonitor.name)" : ""
                Text(workspace.name + monitor).font(.system(.body, design: .monospaced))
            }
        })
    }
}
