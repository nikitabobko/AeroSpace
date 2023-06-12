import Foundation

struct AXObserverWrapper {
    let obs: AXObserver
    let ax: AXUIElement
    let notif: CFString
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    debug("refreshObs")
    refresh()
}
