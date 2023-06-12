import Foundation

class GlobalObserver {
    @objc private static func action() {
//        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }
//        print("notif \(frontmostApp.localizedName)")
//        let window = MacApp.get(frontmostApp).axApp.get(Ax.focusedWindowAttr)
//        print("notif window \(window?.get(Ax.titleAttr))")
//        window

//        let window = NSWorkspace.shared.frontmostApplication?.macApp.focusedWindow
//        print("notif window \(window?.title)")
        refresh()
    }

    static func initObserver() {
//        subscribe(NSWorkspace.didLaunchApplicationNotification)
        // todo subscribe on finder desktop click on different monitors
        subscribe(NSWorkspace.didActivateApplicationNotification)
        subscribe(NSWorkspace.activeSpaceDidChangeNotification)
        subscribe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)





//        window.observe(windowIsDestroyedObs, kAXUIElementDestroyedNotification)


//        subscribe(NSWorkspace.didDeactivateApplicationNotification)
//        subscribe(NSWorkspace.didTerminateApplicationNotification)
//        AXObserverCreate(<#T##application: pid_t##pid_t#>, <#T##callback: AXObserverCallback##ApplicationServices.AXObserverCallback#>, <#T##outObserver: UnsafeMutablePointer<AXObserver?>##Swift.UnsafeMutablePointer<ApplicationServices.AXObserver?>#>)
//        AXObserverAddNotification()


//        subscribe(NSWorkspace.notification)
    }

    private static func subscribe(_ name: NSNotification.Name) {
        NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(action),
                name: name,
                object: nil
        )
    }
}
