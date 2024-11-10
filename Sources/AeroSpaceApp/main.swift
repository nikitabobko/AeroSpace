
import AppKit
import Foundation

let appDelegate = AppDelegate()

let application = NSApplication.shared
application.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
