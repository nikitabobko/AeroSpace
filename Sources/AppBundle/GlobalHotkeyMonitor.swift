import AppKit  // For NSEvent, CGEvent
import Common  // For Config, Command, etc.
import os.lock  // Import for os_unfair_lock

class GlobalHotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var stateLock = os_unfair_lock_s()  // Use os_unfair_lock

    // Precomputed set for O(1) modifier key code lookup
    private static let modifierKeyCodeSet: Set<UInt16> = Set(
        physicalModifierKeyToKeyCode.values)

    // State to track pressed keys, accessed with stateLock
    private var pressedModifierKeyCodes: Set<UInt16> = []
    // Optional: could also track all pressed keys if complex multi-non-modifier chords were needed
    // private var pressedKeyCodes: Set<UInt16> = []

    // For optimized hotkey lookup, accessed with stateLock
    private var bindingsByKeyCode: [UInt16: [HotkeyBinding]] = [:]
    private var lastKnownModeName: String?  // Updated by updateBindingsCache, accessed with stateLock

    // Static shared instance
    @MainActor static let shared = GlobalHotkeyMonitor()

    private init() {
        // Initialization if needed
    }

    @MainActor  // Added @MainActor
    func updateBindingsCache() {
        // This function runs on the MainActor, so it can safely access global activeMode and config.
        guard let currentGlobalActiveModeName = activeMode,
              let modeConfig = config.modes[currentGlobalActiveModeName]
        else {
            // If no active mode or mode config, clear local bindings
            os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
            self.bindingsByKeyCode.removeAll()
            self.lastKnownModeName = nil
            os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
            print(
                "INFO: GlobalHotkeyMonitor cleared bindings cache due to no active mode/config."
            )
            return
        }

        os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
        if self.lastKnownModeName != currentGlobalActiveModeName
            || (self.bindingsByKeyCode.isEmpty && !modeConfig.bindings.isEmpty)
        {
            print(
                "INFO: GlobalHotkeyMonitor rebuilding bindings cache for mode: \(currentGlobalActiveModeName)."
            )
            var freshBindings: [UInt16: [HotkeyBinding]] = [:]  // Build locally
            for (_, binding) in modeConfig.bindings {
                freshBindings[binding.keyCode, default: []].append(binding)
            }
            self.bindingsByKeyCode = freshBindings  // Atomic swap
            self.lastKnownModeName = currentGlobalActiveModeName
        }
        os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
    }

    @MainActor  // Added @MainActor
    func start() {
        guard eventTap == nil else {
            print("WARN: GlobalHotkeyMonitor already started.")
            return
        }

        // Initial population of bindings cache
        updateBindingsCache()

        // The types of events we want to tap.
        // We need keyDown and keyUp to track all key states, including modifiers.
        // flagsChanged can be supplementary or primary for modifiers if direct key up/down for them is noisy or problematic.
        // Let's start with keyDown and keyUp.
        let eventsToTap: CGEventMask =
            (UInt64(1) << CGEventType.keyDown.rawValue)
                | (UInt64(1) << CGEventType.keyUp.rawValue)
                | (UInt64(1) << CGEventType.flagsChanged.rawValue)

        // Create the event tap.
        // '.cghidEventTap' is a common choice for system-wide hardware events.
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,  // Tap into the session event stream. Others: .cgHIDEventTap, .cgAnnotatedSessionEventTap
                place: .headInsertEventTap,  // Insert at the head of the event tap list
                options: .defaultTap,  // Default options
                eventsOfInterest: eventsToTap,
                callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                    // 'refcon' is the UnsafeMutableRawPointer to 'self'
                    guard let refcon else {
                        return Unmanaged.passUnretained(event)
                    }
                    let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(
                        refcon
                    ).takeUnretainedValue()
                    return monitor.handleEvent_Outer(
                        proxy: proxy, type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()  // Pass 'self' to the callback
            )
        else {
            printStderr(
                "ERROR: Failed to create event tap. This usually means AeroSpace requires Accessibility permissions. "
                    + "Please go to System Settings > Privacy & Security > Accessibility, and ensure AeroSpace is enabled. "
                    + "You may need to restart AeroSpace after granting permissions."
            )
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

    @MainActor  // Added @MainActor
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)  // Disable event delivery

            // Invalidate the Mach port. This also removes its run loop sources.
            // One call is sufficient.
            CFMachPortInvalidate(tap)

            // Explicitly removing the source after invalidation is generally not needed
            // as CFMachPortInvalidate should handle it. However, it's kept for now.
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }

            // ARC will handle the release of 'tap' and 'source' when these are set to nil.
            self.runLoopSource = nil
            self.eventTap = nil
            print("INFO: GlobalHotkeyMonitor stopped.")
        }
        os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
        pressedModifierKeyCodes.removeAll()
        // Clear optimized lookup cache
        bindingsByKeyCode.removeAll()
        lastKnownModeName = nil
        os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
    }

    // Entry point from C callback. Runs on event tap thread.
    private nonisolated func handleEvent_Outer(
        proxy: CGEventTapProxy, type cgEventType: CGEventType, event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        var consumed = false

        switch cgEventType {
            case .keyDown:
                os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
                if isModifierKeyCode_Raw(keyCode) {  // Use a raw checker that doesn't need self if possible, or call it on self.
                    pressedModifierKeyCodes.insert(keyCode)
                    os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
                } else {
                    os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
                    if findAndExecuteHotkeyMatch_TapThread(nonModifierKeyCode: keyCode) {
                        consumed = true
                    }
                }
            case .keyUp:
                os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
                if isModifierKeyCode_Raw(keyCode) {
                    pressedModifierKeyCodes.remove(keyCode)
                }
                os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
            case .flagsChanged:
                os_unfair_lock_lock(&stateLock)  // Use os_unfair_lock API
                let changedModifierKeyCode = keyCode
                // Determine if the specific modifier key that changed is now pressed or released.
                guard
                    let physicalKey = physicalModifierKeyToKeyCode.first(where: {
                        $0.value == changedModifierKeyCode
                    })?.key
                else {
                    // Consider if keyCode 0 with flags is a common/ignorable scenario
                    if keyCode != 0 {  // Print warning only if keyCode is not 0
                        print(
                            "WARN: flagsChanged event for unknown modifier keyCode: \(changedModifierKeyCode) (raw flags: \(flags))"
                        )
                    }
                    os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
                    break
                }

                var modifierIsPressed = false
                switch physicalKey {
                    case .leftOption, .rightOption:
                        modifierIsPressed = flags.contains(.maskAlternate)
                    case .leftCommand, .rightCommand:
                        modifierIsPressed = flags.contains(.maskCommand)
                    case .leftShift, .rightShift: modifierIsPressed = flags.contains(.maskShift)
                    case .leftControl, .rightControl:
                        modifierIsPressed = flags.contains(.maskControl)
                    case .function: modifierIsPressed = flags.contains(.maskSecondaryFn)
                }

                if modifierIsPressed {
                    pressedModifierKeyCodes.insert(changedModifierKeyCode)
                } else {
                    pressedModifierKeyCodes.remove(changedModifierKeyCode)
                }
                os_unfair_lock_unlock(&stateLock)  // Use os_unfair_lock API
            default:
                break
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }

    // This function will be called from the tap thread (nonisolated context)
    // It needs to handle its own synchronization for shared state.
    private func findAndExecuteHotkeyMatch_TapThread(nonModifierKeyCode: UInt16) -> Bool {
        // Copy shared data under lock first
        os_unfair_lock_lock(&stateLock)
        let candidateBindingsForKeyCode = self.bindingsByKeyCode[nonModifierKeyCode] ?? []
        let localPressedModifierKeyCodes = self.pressedModifierKeyCodes
        os_unfair_lock_unlock(&stateLock)

        // Proceed with matching on local copies if candidates exist
        guard !candidateBindingsForKeyCode.isEmpty else {
            return false
        }

        var currentPhysicalKeys = Set<PhysicalModifierKey>()
        var activeGenericTypes = Set<GenericModifierType>()

        for pressedKc in localPressedModifierKeyCodes {
            if let physicalKey = physicalModifierKeyToKeyCode.first(where: {
                $0.value == pressedKc
            })?.key {
                currentPhysicalKeys.insert(physicalKey)
                if let genericType = physicalKey.genericType {
                    activeGenericTypes.insert(genericType)
                }
            }
        }

        for binding in candidateBindingsForKeyCode {  // Iterate over the local copy
            guard binding.exactModifiers.isSubset(of: currentPhysicalKeys) else {
                continue
            }

            var genericMatch = true
            for genModType in binding.genericModifiers {
                if !activeGenericTypes.contains(genModType) {
                    genericMatch = false
                    break
                }
            }
            guard genericMatch else { continue }

            let bindingEffectiveModifierCount =
                binding.exactModifiers.count + binding.genericModifiers.count
            if currentPhysicalKeys.count == bindingEffectiveModifierCount {
                // Match found! No lock needed here before dispatching.
                print("INFO: Hotkey matched: \(binding.descriptionWithKeyNotation)")
                DispatchQueue.main.async {
                    Task {
                        try await runSession(
                            .hotkeyBinding, .checkServerIsEnabledOrDie
                        ) { () throws in
                            _ = try await binding.commands.runCmdSeq(
                                .defaultEnv, .emptyStdin)
                        }
                    }
                }
                return true  // Consume event
            }
        }
        return false  // No match found among candidates
    }

    // Helper function to check if a keycode is a modifier. Can be called with lock held or not, doesn't modify state.
    // Renamed from isModifierKeyCode to avoid confusion with any potential @MainActor version.
    private func isModifierKeyCode_Raw(_ keyCode: UInt16) -> Bool {
        GlobalHotkeyMonitor.modifierKeyCodeSet.contains(keyCode)  // Use the precomputed set
    }
}

// Removed PhysicalModifierKey.genericType extension, will be moved to keysMap.swift
// extension PhysicalModifierKey { ... }
