class TrayModel: ObservableObject {
    static let shared = TrayModel()

    private init() {}

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name // config.first?.name ?? "W: 1"
}
