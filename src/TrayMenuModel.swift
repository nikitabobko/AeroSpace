public class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
}

func updateTrayText() {
    let sortedMonitors = sortedMonitors
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first?.lets { "[\($0)] " } ?? "") +
        sortedMonitors
            .map {
                ($0.activeWorkspace == Workspace.focused && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
            }
            .joined(separator: " │ ")
}
