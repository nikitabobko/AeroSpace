import AppKit  // For NSEvent, CGEvent
import Common  // For Config, Command, etc.

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

	// The mechanism is to read from global `config` and `activeMode`
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
		let eventsToTap: CGEventMask =
			(1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
			| (1 << CGEventType.flagsChanged.rawValue)

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
					return monitor.handleEvent(
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

	private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
		-> Unmanaged<CGEvent>?
	{
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
			guard
				let physicalKey = physicalModifierKeyToKeyCode.first(where: {
					$0.value == changedModifierKeyCode
				})?.key
			else {
				// Unknown modifier key code that caused flagsChanged, should not happen if our maps are complete.
				print(
					"WARN: flagsChanged event for unknown modifier keyCode: \(changedModifierKeyCode)"
				)
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

		// 1. Determine current state of pressed modifiers
		var currentPhysicalKeys = Set<PhysicalModifierKey>()
		var activeGenericTypes = Set<GenericModifierType>()

		for pressedKc in self.pressedModifierKeyCodes {
			if let physicalKey = physicalModifierKeyToKeyCode.first(where: {
				$0.value == pressedKc
			})?.key {
				currentPhysicalKeys.insert(physicalKey)
				// Determine generic type from physical key
				switch physicalKey {
				case .leftOption, .rightOption: activeGenericTypes.insert(.option)
				case .leftCommand, .rightCommand:
					activeGenericTypes.insert(.command)
				case .leftControl, .rightControl:
					activeGenericTypes.insert(.control)
				case .leftShift, .rightShift: activeGenericTypes.insert(.shift)
				case .function: break  // `fn` doesn't have a generic counterpart in GenericModifierType
				}
			}
		}

		for (_, binding) in modeConfig.bindings {
			if binding.keyCode == nonModifierKeyCode {
				// Perform matching based on exact and generic modifiers

				// Rule A: All exact modifiers in the binding must be currently pressed
				guard binding.exactModifiers.isSubset(of: currentPhysicalKeys)
				else {
					continue  // Next binding
				}

				// Rule B: All generic modifiers in the binding must be currently active
				// AND ensure that if a generic is specified, no specific of that type is in exactModifiers (parser should prevent this, but good for safety)
				var genericMatch = true
				for genModType in binding.genericModifiers {
					if !activeGenericTypes.contains(genModType) {
						genericMatch = false
						break
					}
					// Parser validation should ensure exactModifiers doesn't contain specifics if generic is used for same type.
					// e.g. if binding.genericModifiers has .option, binding.exactModifiers shouldn't have .leftOption
				}
				guard genericMatch else {
					continue  // Next binding
				}

				// Rule C: Count check - the number of distinct physical modifiers pressed must match the number intended by the binding.
				// Number of modifiers intended by binding:
				// This assumes parser enforces that exactModifiers and genericModifiers are for distinct modifier *types*.
				// e.g., can't have exact lalt AND generic alt. Only one defines the 'option' type part of the binding.

				// More precise count: total number of active physical keys must match what the binding implies.
				// A binding like `alt-shift-h` implies two distinct modifier keys are involved (one option, one shift).
				// A binding like `lalt-ralt-h` implies two distinct modifier keys are involved (left option, right option).
				let bindingEffectiveModifierCount =
					binding.exactModifiers.count
					+ binding.genericModifiers.count
				// This count must be validated by the parser: e.g. `alt-lalt-h` is invalid.
				// If parser is correct, `binding.exactModifiers` and `binding.genericModifiers` don't specify the same base modifier type.

				if currentPhysicalKeys.count == bindingEffectiveModifierCount {
					// If all above checks pass, it's a match.
					print(
						"INFO: Hotkey matched: \(binding.descriptionWithKeyNotation)"
					)
					Task {
						try await runSession(
							.hotkeyBinding, .checkServerIsEnabledOrDie
						) { () throws in
							_ = try await binding.commands.runCmdSeq(
								.defaultEnv, .emptyStdin)
						}
					}
					return true  // Consume event
				}
			}
		}
		return false
	}
}

// Helper extension for PhysicalModifierKey to get its generic type (if any)
// This should ideally be in keysMap.swift or a shared location if GenericModifierType is there.
// For now, adding it here for GlobalHotkeyMonitor's use.
extension PhysicalModifierKey {
	fileprivate var genericType: GenericModifierType? {
		switch self {
		case .leftOption, .rightOption: return .option
		case .leftCommand, .rightCommand: return .command
		case .leftControl, .rightControl: return .control
		case .leftShift, .rightShift: return .shift
		case .function: return nil  // Fn is always specific
		}
	}
}
