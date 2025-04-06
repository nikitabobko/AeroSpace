import AppKit
import Common

/// The subscription is active as long as you keep this class in memory
class AxSubscription {
    let obs: AXObserver
    let ax: AXUIElement
    let axThreadToken: AxAppThreadToken = axTaskLocalAppThreadToken ?? dieT("axTaskLocalAppThreadToken is not initialized")
    var notifKeys: Set<String> = []

    private init(obs: AXObserver, ax: AXUIElement) {
        check(!Thread.current.isMainThread)
        self.obs = obs
        self.ax = ax
    }

    private func subscribe(_ key: String) -> Bool {
        axThreadToken.checkEquals(axTaskLocalAppThreadToken)
        if AXObserverAddNotification(obs, ax, key as CFString, nil) == .success {
            notifKeys.insert(key)
            return true
        } else {
            return false
        }
    }

    static func bulkSubscribe(_ nsApp: NSRunningApplication, _ ax: AXUIElement, _ handlerToNotifKeyMapping: HandlerToNotifKeyMapping) -> [AxSubscription] {
        var result: [AxSubscription] = []
        var visitedNotifKeys: Set<String> = []
        for (handler, notifKeys) in handlerToNotifKeyMapping {
            guard let obs = AXObserver.new(nsApp.processIdentifier, handler) else { return [] }
            let subscription = AxSubscription(obs: obs, ax: ax)
            for key: String in notifKeys {
                assert(visitedNotifKeys.insert(key).inserted)
                if !subscription.subscribe(key) { return [] }
            }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
            result.append(subscription)
        }
        return result
    }

    deinit {
        axThreadToken.checkEquals(axTaskLocalAppThreadToken)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
        for notifKey in notifKeys {
            AXObserverRemoveNotification(obs, ax, notifKey as CFString)
        }
    }
}

typealias HandlerToNotifKeyMapping = [(AXObserverCallback, [String])]
