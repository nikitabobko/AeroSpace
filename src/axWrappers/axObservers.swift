import Foundation

struct AXObserverWrapper {
    let obs: AXObserver
    let ax: AXUIElement
    let notif: CFString
}

func genericObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    print("genericObs")
    refresh()
}
