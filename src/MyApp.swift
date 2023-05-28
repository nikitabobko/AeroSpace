import Foundation
import HotKey
import Cocoa
import CoreFoundation
import AppKit
import SwiftUI

// todo extract into settings
let settings = [
    Setting(id: "RRR", hotkey: .r, modifiers: [.option]),
    Setting(id: "PPP", hotkey: .p, modifiers: [.option]),
]

struct Setting: Identifiable {
    let id: String
    let hotkey: Key
    let modifiers: NSEvent.ModifierFlags
}

@main
struct MyApp: App {
    var hotKeys: [HotKey] = []
    @StateObject var viewModel = ViewModel.shared

    init() {
        checkAccessibilityPermissions()
        Observer.initObserver()
        for setting in settings {
            hotKeys.append(HotKey(key: setting.hotkey, modifiers: setting.modifiers, keyUpHandler: {
                ViewModel.shared.changeWorkspace(setting.id)
            }))
        }
        detectNewWindows()
        test()
    }

    var body: some Scene {
        MenuBarExtra {
            Text("Workspaces:")
            ForEach(settings) { setting in
                Button {
                    viewModel.changeWorkspace(setting.id)
                } label: {
                    Toggle(isOn: setting.id == viewModel.currentWorkspaceName
                            ? Binding(get: { true }, set: { _, _ in })
                            : Binding(get: { false }, set: { _, _ in })) {
                        Text(setting.id).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
            Button("Quit AeroSpace") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.currentWorkspaceName)
        }
    }
}
