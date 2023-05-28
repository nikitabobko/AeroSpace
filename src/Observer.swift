import Foundation

class Observer {
    @objc private static func action() {
        print("notif")
    }

    static func initObserver() {
//        subscribe(NSWorkspace.didLaunchApplicationNotification)
//        subscribe(NSWorkspace.didActivateApplicationNotification)
//        subscribe(NSWorkspace.didDeactivateApplicationNotification)
//        subscribe(NSWorkspace.didTerminateApplicationNotification)
//        AXObserverCreate(<#T##application: pid_t##pid_t#>, <#T##callback: AXObserverCallback##ApplicationServices.AXObserverCallback#>, <#T##outObserver: UnsafeMutablePointer<AXObserver?>##Swift.UnsafeMutablePointer<ApplicationServices.AXObserver?>#>)
//        AXObserverAddNotification()

        kAXMovedNotification
        kAXResizedNotification
        kAXWindowCreatedNotification
        kAXSheetCreatedNotification
        kAXWindowDeminiaturizedNotification
        kAXWindowMiniaturizedNotification
        kAXFocusedWindowChangedNotification
        kAXFocusedUIElementChangedNotification
        kAXUIElementDestroyedNotification

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
