import Foundation
import HotKey
import Cocoa
import CoreFoundation
import AppKit
import SwiftUI

@main
struct macos_window_manager_swiftApp: App {
    var hotKeys: [HotKey] = []
    init() {
        hotKeys.append(HotKey(key: .r, modifiers: [.command, .option], keyUpHandler: { print("hi") }))
        accessibilityPermissions()
        windows()
        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            foo()
            print("wtf")
        }
    }

    func foo() {
        command = "C"
    }

    @State private var command: String = "A"

    var body: some Scene {
        MenuBarExtra(
                content: {
                    Button("A") { command = "A" }
                    Button("B") { command = "B" }
                    Divider()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                },
                label: {
                    Text(command)
                }
        )
    }
}

//let hotkey = HotKey(key: .r, modifiers: [.command, .option], keyUpHandler: {
//    print("hi!")
//})
//
//
////allWindowsOnCurrentMacOsSpace()
//
//windows()
//exit(0)
