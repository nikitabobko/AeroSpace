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
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first?.lets { TrayItem(type: .mode, name: $0.uppercased(), isActive: true) }
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

enum TrayItemType: String, Hashable {
    case mode
    case monitor
}

private let validNumbers = "0" ... "9"
private let validLetters = "A" ... "Z"

struct TrayItem: Hashable, Identifiable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    var systemImageName: String? {
        // System image type is only valid for single number and single capital char workspace name
        guard name.count == 1 else { return nil }
        guard validNumbers.contains(name) || validLetters.contains(name) else { return nil }
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
    var id: String {
        return type.rawValue + name
    }
}
