import AppBundle
import SwiftUI

// This file is shared between SPM and xcode project

@MainActor // macOS 13
@main
struct AeroSpaceApp: App {
    @MainActor // macOS 13
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var appearance = Appearance.shared

    init() {
        initAppBundle()
    }

    @MainActor // macOS 13
    var body: some Scene {
        menuBar(viewModel: viewModel, appearance: appearance)
    }
}
