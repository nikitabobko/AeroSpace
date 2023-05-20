import Foundation
import HotKey
import Cocoa
import CoreFoundation
import AppKit
import SwiftUI

@main
struct macos_window_manager_swiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
