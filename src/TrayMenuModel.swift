class TrayMenuModel: ObservableObject {
    static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
}

func updateTrayText() {
    TrayMenuModel.shared.trayText = monitors
        .sorted(using: [SelectorComparator(selector: \.rect.minX), SelectorComparator(selector: \.rect.minY)])
        .map(\.activeWorkspace.name)
        .joined(separator: " │ ")
}
