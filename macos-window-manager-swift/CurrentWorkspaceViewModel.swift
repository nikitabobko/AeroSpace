import Foundation

class ViewModel: ObservableObject {
    static let shared = ViewModel()

    @Published var currentWorkspace: String = initialWorkspace
}
