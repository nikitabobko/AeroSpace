import AppKit
import Common
import Foundation
import HotKey

// Carbon global hot keys (which is what the HotKey dependency uses) can only express
// "device independent" modifiers: there is a single `.option` flag, and no way to say
// "left alt, but not right alt". That is a problem on layouts where right alt is needed
// to type characters (`@`, `#`, `€` on the Spanish layout, for example): a plain `alt-2`
// binding swallows right-alt-2 too, and `@` becomes untypeable.
//
// `CGEvent` does carry the side information, in the low ("device dependent") bits of its
// flags. So bindings that name a side (`left-alt-2`) bypass HotKey entirely and are
// matched here, in a CGEventTap installed ahead of Carbon. Anything the tap doesn't claim
// is passed through untouched, which is what lets right-alt-2 reach the focused app.
//
// Bindings without a side keep using HotKey, exactly as before.

/// A modifier that a binding pinned to one physical side of the keyboard.
enum SidedModifier: Sendable, Hashable, CaseIterable {
    case leftShift, rightShift
    case leftControl, rightControl
    case leftOption, rightOption
    case leftCommand, rightCommand

    /// The device dependent bit macOS sets in `CGEvent.flags`.
    /// `NSEvent.ModifierFlags` masks these away, which is the whole reason this file exists.
    var deviceMask: UInt64 {
        switch self {
            case .leftControl: 0x0000_0001
            case .leftShift: 0x0000_0002
            case .rightShift: 0x0000_0004
            case .leftCommand: 0x0000_0008
            case .rightCommand: 0x0000_0010
            case .leftOption: 0x0000_0020
            case .rightOption: 0x0000_0040
            case .rightControl: 0x0000_2000
        }
    }

    /// The side independent flag this modifier also implies.
    var genericFlag: NSEvent.ModifierFlags {
        switch self {
            case .leftShift, .rightShift: .shift
            case .leftControl, .rightControl: .control
            case .leftOption, .rightOption: .option
            case .leftCommand, .rightCommand: .command
        }
    }

    /// The same modifier on the other side of the keyboard. It must *not* be held down,
    /// otherwise `left-alt-2` would also fire on right-alt-2.
    var otherSide: SidedModifier {
        switch self {
            case .leftShift: .rightShift
            case .rightShift: .leftShift
            case .leftControl: .rightControl
            case .rightControl: .leftControl
            case .leftOption: .rightOption
            case .rightOption: .leftOption
            case .leftCommand: .rightCommand
            case .rightCommand: .leftCommand
        }
    }

    /// How the modifier is spelled in the config, e.g. `left-alt`.
    var notation: String {
        switch self {
            case .leftShift: "left-shift"
            case .rightShift: "right-shift"
            case .leftControl: "left-ctrl"
            case .rightControl: "right-ctrl"
            case .leftOption: "left-alt"
            case .rightOption: "right-alt"
            case .leftCommand: "left-cmd"
            case .rightCommand: "right-cmd"
        }
    }

    /// Stable ordering, so that `descriptionWithKeyCode` is deterministic.
    var sortOrder: Int {
        switch self {
            case .leftOption: 0
            case .rightOption: 1
            case .leftControl: 2
            case .rightControl: 3
            case .leftCommand: 4
            case .rightCommand: 5
            case .leftShift: 6
            case .rightShift: 7
        }
    }
}

let sidedModifiersMap: [String: SidedModifier] = Dictionary(
    uniqueKeysWithValues: SidedModifier.allCases.map { ($0.notation, $0) },
)

extension Set<SidedModifier> {
    func toString() -> String {
        sorted { $0.sortOrder < $1.sortOrder }.map(\.notation).joined(separator: "-")
    }
}

// MARK: - The tap

@MainActor private var eventTap: CFMachPort? = nil
/// keyCode -> bindings that want that key. Rebuilt on every mode switch and config reload.
@MainActor private var tapBindings: [Int64: [HotkeyBinding]] = [:]
/// keyDowns we swallowed, so that we can swallow the matching keyUp and the auto-repeats.
/// Letting a lone keyUp through leaves apps thinking the key is still held down.
@MainActor private var swallowedKeyCodes: Set<Int64> = []

/// Called on every mode switch and config reload with the bindings that are active *now*.
@MainActor func setEventTapBindings(_ bindings: [HotkeyBinding]) {
    var table: [Int64: [HotkeyBinding]] = [:]
    for binding in bindings where !binding.sidedModifiers.isEmpty {
        table[Int64(binding.keyCode.carbonKeyCode), default: []].append(binding)
    }
    tapBindings = table
    // swallowedKeyCodes is deliberately NOT cleared here: a binding that switches mode
    // (left-alt-shift-semicolon = 'mode service') swallows its keyDown and lands here before
    // its keyUp arrives. Clearing would let that lone keyUp through to the focused app.
    // Don't pay for the tap (nor ask for it) unless a sided binding is actually configured.
    if !table.isEmpty {
        startEventTapIfNeeded()
    }
}

@MainActor private func startEventTapIfNeeded() {
    if eventTap != nil { return }
    let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
    guard let tap = unsafe CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(mask),
        callback: eventTapCallback,
        userInfo: nil,
    ) else {
        MessageModel.shared.message = Message(
            body: """
                AeroSpace failed to install a keyboard event tap.

                'left-alt'/'right-alt' style bindings will not work. Regular bindings are unaffected.
                This usually means the Accessibility permission is missing or was granted to a
                different build of AeroSpace. Check System Settings > Privacy & Security > Accessibility.
                """,
            containsWarnings: true,
        )
        return
    }
    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
    // The run loop source lives on the main run loop, so this always runs on the main thread.
    // CGEvent isn't Sendable, so only plain values cross into the @MainActor functions below;
    // the event itself never leaves this scope.
    let passThrough = unsafe Unmanaged.passUnretained(event)
    switch type {
        // macOS disables the tap if this callback is too slow, and across some input switches.
        // Without re-enabling, sided bindings would silently stop working until the next restart.
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            MainActor.assumeIsolated { reEnableEventTap() }
            return unsafe passThrough
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let rawFlags = event.flags.rawValue
            let swallow = MainActor.assumeIsolated {
                handleTappedKeyDown(keyCode: keyCode, isRepeat: isRepeat, rawFlags: rawFlags)
            }
            return unsafe swallow ? nil : passThrough
        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let swallow = MainActor.assumeIsolated { handleTappedKeyUp(keyCode: keyCode) }
            return unsafe swallow ? nil : passThrough
        default:
            return unsafe passThrough
    }
}

@MainActor private func reEnableEventTap() {
    if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
}

/// Returns true if the event must be swallowed, i.e. not delivered to the focused app.
@MainActor private func handleTappedKeyDown(keyCode: Int64, isRepeat: Bool, rawFlags: UInt64) -> Bool {
    // Carbon hot keys don't auto-repeat, so neither do we. Holding left-alt-2 down must not
    // queue up a hundred workspace switches. Still swallowed, so nothing gets typed either.
    if isRepeat { return swallowedKeyCodes.contains(keyCode) }
    guard let binding = tapBindings[keyCode]?.first(where: { $0.matches(rawFlags: rawFlags) }) else {
        swallowedKeyCodes.remove(keyCode)
        return false
    }
    swallowedKeyCodes.insert(keyCode)
    Task.startUnstructured { try await runHotkeyBinding(binding) }
    return true
}

@MainActor private func handleTappedKeyUp(keyCode: Int64) -> Bool {
    swallowedKeyCodes.remove(keyCode) != nil
}

extension HotkeyBinding {
    /// Does this binding describe exactly the modifiers held down in `rawFlags`?
    func matches(rawFlags raw: UInt64) -> Bool {
        // Side independent part: the same check Carbon would do. `==` rather than `contains`,
        // so that cmd-left-alt-h doesn't fire a left-alt-h binding.
        let generic = NSEvent.ModifierFlags(rawValue: UInt(raw))
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad, .help])
        if generic != modifiers { return false }
        // Side dependent part. `left-alt-2` requires left alt down *and* right alt up --
        // the generic check above can't tell them apart, both are just `.option`.
        for sided in sidedModifiers {
            if raw & sided.deviceMask == 0 { return false }
            if raw & sided.otherSide.deviceMask != 0 { return false }
        }
        return true
    }
}
