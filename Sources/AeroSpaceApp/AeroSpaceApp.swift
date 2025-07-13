import AppBundle
import SwiftUI

// This file is shared between SPM and xcode project

@MainActor // macOS 13
@main
struct AeroSpaceApp: App {
    @MainActor // macOS 13
    @StateObject var viewModel = TrayMenuModel.shared
    @MainActor // macOS 13
    @StateObject var messageModel = MessageModel.shared
    @Environment(\.openWindow) var openWindow

    init() {
        initAppBundle()
    }

    @MainActor // macOS 13
    var body: some Scene {
        menuBar(viewModel: viewModel)
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
