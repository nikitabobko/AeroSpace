import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    private init() {
    }

    @Published var focusedWorkspaceTrayText: String = currentEmptyWorkspace.name // settings.first?.name ?? "W: 1"
}

