class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    TrayMenuModel.shared.trayText = sortedMonitors.map(\.activeWorkspace.name).joined(separator: " │ ")
}
