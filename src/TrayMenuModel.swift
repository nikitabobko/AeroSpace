class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    switch config.trayIconContent {
    case .active_workspace:
        TrayMenuModel.shared.trayText = focusedWorkspaceName
    case .active_workspaces:
        TrayMenuModel.shared.trayText = NSScreen.screens
            .sorted(using: [SelectorComparator { $0.rect.minX }, SelectorComparator { $0.rect.minY }])
            .map { $0.monitor.getActiveWorkspace().name }
            .joined(separator: config.trayIconWorkspacesSeparator)
    case .icon:
        TrayMenuModel.shared.trayText = "AS" // todo icon
    }
}
