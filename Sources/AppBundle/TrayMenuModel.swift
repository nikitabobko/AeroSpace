import AppKit
import Common

public class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    @Published var trayItems: [TrayItem] = []
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
    @Published var experimentalUISettings: ExperimentalUISettings = ExperimentalUISettings()
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
    var items = sortedMonitors.map {
        TrayItem(type: .monitor, name: $0.activeWorkspace.name, isActive: $0.activeWorkspace == focus.workspace && sortedMonitors.count > 1)
    }
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first?.lets { TrayItem(type: .mode, name: String($0), isActive: true) }
    if let mode {
        items.insert(mode, at: 0)
    }
    TrayMenuModel.shared.trayItems = items
}

struct WorkspaceViewModel: Hashable {
    let name: String
    let suffix: String
    let isFocused: Bool
}

enum TrayItemType: String {
    case mode
    case monitor
}

struct TrayItem: Hashable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    var systemImageName: String {
        let lowercasedName = name.lowercased()
        switch type {
            case .mode:
                return "\(lowercasedName).circle"
            case .monitor:
                if isActive {
                    return "\(lowercasedName).square.fill"
                } else {
                    return "\(lowercasedName).square"
                }
        }
    }
}
