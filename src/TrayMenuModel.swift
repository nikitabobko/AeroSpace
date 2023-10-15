class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    TrayMenuModel.shared.trayText = NSScreen.screens
        .sorted(using: [SelectorComparator(selector: \.rect.minX), SelectorComparator(selector: \.rect.minY)])
        .map { $0.monitor.getActiveWorkspace().name }
        .joined(separator: " │ ")
}
