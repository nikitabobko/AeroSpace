import Foundation
import HotKey
import Cocoa
import CoreFoundation
import AppKit
import SwiftUI

@main
struct macos_window_manager_swiftApp: App {
    init() {
        let hotKey = HotKey(key: .r, modifiers: [.command, .option], keyUpHandler: { print("hi") })
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
//accessibilityPermissions()
////allWindowsOnCurrentMacOsSpace()
//
//windows()
//exit(0)
