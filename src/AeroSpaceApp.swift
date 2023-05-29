import Foundation
import HotKey
import Cocoa
import CoreFoundation
import AppKit
import SwiftUI

// todo extract into settings
let settings = [
    Setting(id: "111", hotkey: .one, modifiers: [.option]),
    Setting(id: "222", hotkey: .two, modifiers: [.option]),
]

struct Setting: Identifiable {
    let id: String
    let hotkey: Key
    let modifiers: NSEvent.ModifierFlags
}

@main
struct AeroSpaceApp: App {
    var hotKeys: [HotKey] = [] // Keep hotkeys in memory
    @StateObject var viewModel = ViewModel.shared

    init() {
        checkAccessibilityPermissions()
        Observer.initObserver()
        for setting in settings {
            hotKeys.append(HotKey(key: setting.hotkey, modifiers: setting.modifiers, keyUpHandler: {
                ViewModel.shared.changeWorkspace(setting.id)
            }))
        }
        refresh()
        test()
    }

    var body: some Scene {
        MenuBarExtra {
            Text("AeroSpace v\(Bundle.main.appVersion)")
            Divider()
            Text("Workspaces:")
            // todo show only non empty workspaces
            //      Or create two groups? (non empty group and empty group)
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
            Button("Quit AeroSpace") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.currentWorkspaceName)
        }
    }
}
