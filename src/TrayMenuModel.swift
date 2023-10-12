class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    TrayMenuModel.shared.trayText = NSScreen.screens
        .sorted(using: [SelectorComparator { $0.rect.minX }, SelectorComparator { $0.rect.minY }])
        .map { $0.monitor.getActiveWorkspace().name }
        .joined(separator: " │ ")
}
