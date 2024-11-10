import AppKit
import Common

public class TrayMenuModel: ObservableObject {
    public static let shared = TrayMenuModel()

    private init() {}

    @Published public var trayText: String = ""
    /// Is "layouting" enabled
    @Published public var isEnabled: Bool = true
    
}

func updateTrayText() {
    let sortedMonitors = sortedMonitors
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first?.lets { "[\($0)] " } ?? "") +
        sortedMonitors
        .map {
            ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
        }
        .joined(separator: " │ ")
}
