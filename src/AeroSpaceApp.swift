import HotKey
import SwiftUI
import Common

@main
struct AeroSpaceApp: App {
    @StateObject var viewModel = TrayMenuModel.shared

    init() {
        _bridgedHeader = BridgedHeaderImpl()
        initAppBundle()
    }

    var body: some Scene {
        menuBar(viewModel: viewModel)
    }
}

// It's not possible to define bridged-headers in swift package manager :(
struct BridgedHeaderImpl: BridgedHeader {
    func containingWindowId(_ ax: AXUIElement) -> CGWindowID? {
        var cgWindowId = CGWindowID()
        return _AXUIElementGetWindow(ax, &cgWindowId) == .success ? cgWindowId : nil
    }
}
