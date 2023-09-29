class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name // config.first?.name ?? "W: 1"
}

func updateFocusedWorkspaceTrayText(newWorkspace: String) {
    if TrayMenuModel.shared.focusedWorkspaceTrayText != newWorkspace {
        previousWorkspaceName = TrayMenuModel.shared.focusedWorkspaceTrayText
    }
    TrayMenuModel.shared.focusedWorkspaceTrayText = newWorkspace
}

var previousWorkspaceName: String? = nil
