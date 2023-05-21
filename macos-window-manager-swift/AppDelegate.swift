import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        accessibilityPermissions()
//        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            windows()
//        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "1.circle", accessibilityDescription: "1")
        }
        setupMenus()
    }
    
    func setupMenus() {
        // 1
        let menu = NSMenu()
        
        // 2
        let one = NSMenuItem(title: "One", action: #selector(didTapOne) , keyEquivalent: "1")
        menu.addItem(one)
        
        let two = NSMenuItem(title: "Two", action: #selector(didTapTwo) , keyEquivalent: "2")
        menu.addItem(two)
        
        let three = NSMenuItem(title: "Three", action: #selector(didTapThree) , keyEquivalent: "3")
        menu.addItem(three)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // 3
        statusItem.menu = menu
    }
    
    private func changeStatusBarButton(number: Int) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "\(number).circle", accessibilityDescription: number.description)
        }
    }
    
    @objc func didTapOne() {
        changeStatusBarButton(number: 1)
    }
    
    @objc func didTapTwo() {
        changeStatusBarButton(number: 2)
    }
    
    @objc func didTapThree() {
        changeStatusBarButton(number: 3)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
