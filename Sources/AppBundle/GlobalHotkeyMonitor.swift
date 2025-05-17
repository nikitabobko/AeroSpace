import AppKit // For NSEvent, CGEvent
import Common // For Config, Command, etc.

// We will not import HotKey here as we are replacing it.

@MainActor
class GlobalHotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // State to track pressed keys
    // Using UInt16 for virtual key codes
    private var pressedModifierKeyCodes: Set<UInt16> = []
    // Optional: could also track all pressed keys if complex multi-non-modifier chords were needed
    // private var pressedKeyCodes: Set<UInt16> = []

    // TODO: We'll need a mechanism to get the active bindings
    // This might be passed in or accessed via a shared context/config reference.
    // For now, assuming access to 'config' and 'activeMode' (defined in HotkeyBinding.swift context)

    init() {
        // Initialization if needed
    }

    func start() {
        guard eventTap == nil else {
            print("WARN: GlobalHotkeyMonitor already started.")
            return
        }

        // The types of events we want to tap.
        // We need keyDown and keyUp to track all key states, including modifiers.
        // flagsChanged can be supplementary or primary for modifiers if direct key up/down for them is noisy or problematic.
        // Let's start with keyDown and keyUp.
        let eventsToTap: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        // Create the event tap.
        // '.cghidEventTap' is a common choice for system-wide hardware events.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, // Tap into the session event stream. Others: .cgHIDEventTap, .cgAnnotatedSessionEventTap
            place: .headInsertEventTap, // Insert at the head of the event tap list
            options: .defaultTap,      // Default options
            eventsOfInterest: eventsToTap,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                // 'refcon' is the UnsafeMutableRawPointer to 'self'
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque() // Pass 'self' to the callback
        ) else {
            printStderr("ERROR: Failed to create event tap. This usually means AeroSpace requires Accessibility permissions. " +
                "Please go to System Settings > Privacy & Security > Accessibility, and ensure AeroSpace is enabled. " +
                "You may need to restart AeroSpace after granting permissions.")
            // TODO: Better error handling - inform user, guide to permissions.
            // Consider showing a user-facing alert if possible from this context,
            // or setting a flag that the UI can pick up to show an alert.
            // Example to open settings (use with caution, might need main thread if called from background):
            // NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            return
        }

        // Create a run loop source and add it to the current run loop.
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            printStderr("ERROR: Failed to create run loop source for event tap.")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source

        print("INFO: GlobalHotkeyMonitor started.")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            // CFMachPortInvalidate(tap) // Invalidating the port also removes the run loop source.
            // However, it's often better to remove the source explicitly.
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            // CFRelease(tap) // tap is a CFMachPort, managed by ARC when interacting with Swift types like CFMachPort?
            // If directly using CFTypeRef, manual CFRelease would be needed.
            // Swift handles this for optional CF types.
            self.runLoopSource = nil
            self.eventTap = nil
            print("INFO: GlobalHotkeyMonitor stopped.")
        }
        pressedModifierKeyCodes.removeAll()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
            case .keyDown:
                if isModifierKeyCode(keyCode) {
                    pressedModifierKeyCodes.insert(keyCode)
                } else {
                    if checkForHotkeyMatch(nonModifierKeyCode: keyCode, event: event) {
                        return nil
                    }
                }
            case .keyUp:
                if isModifierKeyCode(keyCode) {
                    pressedModifierKeyCodes.remove(keyCode)
                } else {
                    // Optionally handle keyUp for non-modifiers if needed for specific command types
                }
            case .flagsChanged:
                // The keyCode in a flagsChanged event is the specific modifier key that changed.
                let changedModifierKeyCode = keyCode
                let newFlagsState = event.flags

                // Determine if the specific modifier key that changed is now pressed or released.
                // This requires knowing which generic flag corresponds to the specific modifier key code.
                guard let physicalKey = physicalModifierKeyToKeyCode.first(where: { $0.value == changedModifierKeyCode })?.key else {
                    // Unknown modifier key code that caused flagsChanged, should not happen if our maps are complete.
                    print("WARN: flagsChanged event for unknown modifier keyCode: \(changedModifierKeyCode)")
                    break
                }

                var modifierIsPressed = false
                switch physicalKey {
                    case .leftOption, .rightOption:
                        modifierIsPressed = newFlagsState.contains(.maskAlternate)
                    case .leftCommand, .rightCommand:
                        modifierIsPressed = newFlagsState.contains(.maskCommand)
                    case .leftShift, .rightShift:
                        modifierIsPressed = newFlagsState.contains(.maskShift)
                    case .leftControl, .rightControl:
                        modifierIsPressed = newFlagsState.contains(.maskControl)
                    case .function:
                        modifierIsPressed = newFlagsState.contains(.maskSecondaryFn)
                }

                if modifierIsPressed {
                    pressedModifierKeyCodes.insert(changedModifierKeyCode)
                } else {
                    pressedModifierKeyCodes.remove(changedModifierKeyCode)
                }
            // print("DEBUG: FlagsChanged: \(physicalKey) (kc: \(changedModifierKeyCode)) is now \(modifierIsPressed ? "pressed" : "released"). Current pressed: \(pressedModifierKeyCodes)")

            default:
                break
        }

        return Unmanaged.passUnretained(event)
    }

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        physicalModifierKeyToKeyCode.values.contains(keyCode)
    }

    private func checkForHotkeyMatch(nonModifierKeyCode: UInt16, event: CGEvent) -> Bool {
        guard let currentActiveMode = activeMode,
              let modeConfig = config.modes[currentActiveMode]
        else {
            return false
        }

        for (_, binding) in modeConfig.bindings {
            if binding.keyCode == nonModifierKeyCode {
                let requiredModifierKeyCodes = Set(binding.specificModifiers.map { physicalModifierKeyToKeyCode[$0]! })

                if requiredModifierKeyCodes == self.pressedModifierKeyCodes {
                    print("INFO: Hotkey matched: \(binding.descriptionWithKeyNotation)")
                    Task {
                        // Use runSession for consistent command execution and error handling
                        // The original binding.descriptionWithKeyCode might be slightly different now if specificModifiers.toString() order changed.
                        // However, we have the direct 'binding.commands' object here.
                        try await runSession(.hotkeyBinding, .checkServerIsEnabledOrDie) { () throws in
                            _ = try await binding.commands.runCmdSeq(.defaultEnv, .emptyStdin)
                        }
                        // TODO: Add more specific error handling for runSession if needed.
                    }
                    // TODO: Make event consumption configurable per binding.
                    // For now, always consume if a binding matches and executes.
                    return true
                }
            }
        }
        return false
    }
}

// Helper extension for PhysicalModifierKey (assuming it's in keysMap.swift or accessible)
extension PhysicalModifierKey {
    func isPressed(in flags: CGEventFlags) -> Bool {
        // This logic needs to map PhysicalModifierKey to the correct CGEventFlags bitmask
        // For example, .leftOption would check for .maskAlternate and also potentially check the keycode if flags alone are not enough
        // For CGEvent.flagsChanged, the keyCode in the event itself is the primary source of truth for *which* modifier changed.
        // The CGEventFlags then tell the *new state* of all flags.

        // A simpler approach for flagsChanged:
        // The event's keyCode IS the modifier that changed.
        // We check if that keyCode is now part of the 'flags'.
        // However, CGEventFlags are like NSEvent.ModifierFlags - they don't distinguish left/right by default in the main bitmask.
        // So, for flagsChanged, we really rely on its `keyCode` field to tell us WHICH specific modifier key triggered it,
        // and then check if that key is "on" in the new flags state (e.g. any option key is on if .maskAlternate is set).
        // This confirms the specific key AND its state.

        // Given that our pressedModifierKeyCodes set is based on individual key codes from keyDown/Up
        // this helper might be more for interpreting the global CGEventFlags if needed elsewhere,
        // or if we were to *only* use flagsChanged.
        // For the current flagsChanged logic, we iterate physicalModifierKeyToKeyCode and check against currentFlags.

        // Let's assume this function helps interpret the global flags state for a *specific* modifier.
        // This is complex because CGEventFlags themselves don't easily give left/right distinction.
        // We are tracking left/right based on their keyCodes directly from keyDown/keyUp/flagsChanged's keyCode.
        // So, the pressedModifierKeyCodes set is our source of truth for specific left/right keys.
        // This function might not be directly used in the flagsChanged logic as revised.

        // If we were to use it, it would look like:
        let code = physicalModifierKeyToKeyCode[self]!
        switch self {
            case .leftOption, .rightOption:
                return flags.contains(.maskAlternate) // And then check 'code' if flags.contains(.maskAlternate)
            case .leftCommand, .rightCommand:
                return flags.contains(.maskCommand)
            case .leftShift, .rightShift:
                return flags.contains(.maskShift)
            case .leftControl, .rightControl:
                return flags.contains(.maskControl)
            case .function:
                return flags.contains(.maskSecondaryFn) // Corrected for CGEventFlags
                // default: return false
        }
        // This is still tricky. The most reliable way is to get key up/down for each modifier via its keycode.
        // For flagsChanged, the keyCode of the event tells *which* modifier changed.
        // The flags then tell the *new state* of *generic* modifiers.
        // So, if flagsChanged says keyCode for Left Alt changed, and event.flags contains .maskAlternate, Left Alt is now on.

        // Revising the flagsChanged logic: iterate known physical modifiers, check if their generic flag is set,
        // and if the specific keycode triggered this event or is generally active.

        // The revised logic in flagsChanged directly updates pressedModifierKeyCodes by checking generic flags
        // and assuming the keyCode from flagsChanged gives the specific key.
        // This helper will be refined if a different strategy for flagsChanged is needed.
        return false // Placeholder as the primary logic is now directly in handleEvent
    }
}
