class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name // config.first?.name ?? "W: 1"
}
