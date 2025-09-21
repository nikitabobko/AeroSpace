import AppKit

struct KeyboardEvent {
    let flags: CGEventFlags
    let keyCode: UInt32
}

final class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: (KeyboardEvent) -> Bool

    init(handler: @escaping (KeyboardEvent) -> Bool) {
        self.handler = handler
        start()
    }

    private func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        self.eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) in
                // We have to use a week reference to self to avoid retain cycles

                if let refcon {
                    let this = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let keyboardEvent = KeyboardEvent(flags: flags, keyCode: UInt32(keyCode))
                    if this.handler(keyboardEvent) {
                        return nil
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque(),
        )

        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }
}
