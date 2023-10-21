class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    TrayMenuModel.shared.trayText = (activeMode.takeIf { $0 != mainModeId }?.first?.lets { "[\($0)] " } ?? "") +
        sortedMonitors.map(\.activeWorkspace.name).joined(separator: " │ ")
}
