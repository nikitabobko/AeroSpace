import AppKit
import Common

public class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
}

@MainActor func updateTrayText() {
    let sortedMonitors = sortedMonitors
    let focus = focus
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first?.lets { "[\($0.uppercased())] " } ?? "") +
        sortedMonitors
        .map {
            ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
        }
        .joined(separator: " │ ")
    TrayMenuModel.shared.workspaces = Workspace.all.map {
        let monitor = $0.isVisible || !$0.isEffectivelyEmpty ? " - \($0.workspaceMonitor.name)" : ""
        return WorkspaceViewModel(name: $0.name, suffix: monitor, isFocused: focus.workspace == $0)
    }
}

struct WorkspaceViewModel {
    let name: String
    let suffix: String
    let isFocused: Bool
}
