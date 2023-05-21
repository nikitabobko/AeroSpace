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
        for setting in settings {
            hotKeys.append(HotKey(key: setting.hotkey, modifiers: setting.modifiers, keyUpHandler: {
                ViewModel.shared.currentWorkspace = setting.id
            }))
        }
        accessibilityPermissions()
        windows()
    }

    var body: some Scene {
        MenuBarExtra {
            Text("Workspaces:")
            ForEach(settings) { setting in
                Button {
                    viewModel.currentWorkspace = setting.id
                } label: {
                    Toggle(isOn: setting.id == viewModel.currentWorkspace
                            ? Binding(get: { true }, set: { _, _ in })
                            : Binding(get: { false }, set: { _, _ in })) {
                        Text(setting.id).font(.system(.body, design: .monospaced))
                    }
                }.keyboardShortcut(KeyEquivalent(setting.hotkey.toChar()), modifiers: .option)
            }
            Divider()
            Button("Quit macos-window-manager") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("Q", modifiers: .command)
        } label: {
            // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
            Text(viewModel.currentWorkspace)
        }
    }
}

extension Key {
    func toChar() -> Character {
       switch self {
       case .a:
           return "A"
       case .b:
           return "B"
       case .c:
           return "C"
       case .d:
           return "D"
       case .e:
           return "e"
       case .f:
           return "F"
       case .g:
           return "G"
       case .h:
           return "H"
       case .i:
           return "I"
       case .j:
           return "J"
       case .k:
           return "K"
       case .l:
           return "L"
       case .m:
           return "M"
       case .n:
           return "N"
       case .o:
           return "O"
       case .p:
           return "P"
       case .q:
           return "Q"
       case .r:
           return "R"
       case .s:
           return "S"
       case .t:
           return "T"
       case .u:
           return "U"
       case .v:
           return "V"
       case .w:
           return "W"
       case .x:
           return "X"
       case .y:
           return "Y"
       case .z:
           return "Z"
       default:
           fatalError("Not recognized: \(self)")
       }
    }
}
