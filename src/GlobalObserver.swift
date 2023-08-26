import Foundation

class GlobalObserver {
    @objc private static func action() {
        refresh()
    }

    static func initObserver() {
        // todo subscribe main monitor changed?
        // todo subscribe monitor configuration changed?
        subscribe(NSWorkspace.didLaunchApplicationNotification)
        subscribe(NSWorkspace.didActivateApplicationNotification)
        subscribe(NSWorkspace.didHideApplicationNotification)
        subscribe(NSWorkspace.didUnhideApplicationNotification)
        subscribe(NSWorkspace.didDeactivateApplicationNotification)
        subscribe(NSWorkspace.activeSpaceDidChangeNotification)
        subscribe(NSWorkspace.didTerminateApplicationNotification)

//        window.observe(windowIsDestroyedObs, kAXUIElementDestroyedNotification)


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
