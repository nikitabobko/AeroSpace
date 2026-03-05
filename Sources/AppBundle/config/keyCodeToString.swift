import Carbon
import Foundation

/// The key code map computed based on the currently selected keyboard layout.
/// Used to translate from key codes to the respective symbols.
@MainActor var currentKeyCodeMap = [UInt32: String]()

/// All the non-changing keys of a key-map.
let baseKeyCodeMap = [
    kVK_F1: "f1",
    kVK_F2: "f2",
    kVK_F3: "f3",
    kVK_F4: "f4",
    kVK_F5: "f5",
    kVK_F6: "f6",
    kVK_F7: "f7",
    kVK_F8: "f8",
    kVK_F9: "f9",
    kVK_F10: "f10",
    kVK_F11: "f11",
    kVK_F12: "f12",
    kVK_F13: "f13",
    kVK_F14: "f14",
    kVK_F15: "f15",
    kVK_F16: "f16",
    kVK_F17: "f17",
    kVK_F18: "f18",
    kVK_F19: "f19",

    kVK_Space: "space",
    kVK_Escape: "esc",
    kVK_Delete: "backspace",
    kVK_ForwardDelete: "forwardDelete",
    kVK_LeftArrow: "left",
    kVK_RightArrow: "right",
    kVK_UpArrow: "up",
    kVK_DownArrow: "down",
    kVK_Help: "help",
    kVK_Home: "home",
    kVK_End: "end",
    kVK_PageUp: "pageUp",
    kVK_PageDown: "pageDown",
    kVK_Tab: "tab",
    kVK_Return: "enter",

    kVK_ANSI_Keypad0: "keypad0",
    kVK_ANSI_Keypad1: "keypad1",
    kVK_ANSI_Keypad2: "keypad2",
    kVK_ANSI_Keypad3: "keypad3",
    kVK_ANSI_Keypad4: "keypad4",
    kVK_ANSI_Keypad5: "keypad5",
    kVK_ANSI_Keypad6: "keypad6",
    kVK_ANSI_Keypad7: "keypad7",
    kVK_ANSI_Keypad8: "keypad8",
    kVK_ANSI_Keypad9: "keypad9",
    kVK_ANSI_KeypadDecimal: "keypadDecimalMark",
    kVK_ANSI_KeypadMultiply: "keypadMultiply",
    kVK_ANSI_KeypadPlus: "keypadPlus",
    kVK_ANSI_KeypadClear: "keypadClear",
    kVK_ANSI_KeypadDivide: "keypadDivide",
    kVK_ANSI_KeypadEnter: "keypadEnter",
    kVK_ANSI_KeypadMinus: "keypadMinus",
    kVK_ANSI_KeypadEquals: "keypadEqual",
]

private func keyCodeToString(_ keyCode: UInt16) -> String? {
    if let s = baseKeyCodeMap[Int(keyCode)] {
        return s
    }

    var currentKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    var rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)

    if rawLayoutData == nil {
        currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
        rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
    }

    // Get the layout
    let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
    let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 16)
    var actualLength = 0

    let error = UCKeyTranslate(
        layout,
        keyCode,
        UInt16(kUCKeyActionDisplay),
        0, // No modifiers
        UInt32(LMGetKbdType()),
        UInt32(kUCKeyTranslateNoDeadKeysMask),
        &deadKeyState,
        chars.count,
        &actualLength,
        &chars,
    )

    guard error == noErr else { return nil }

    let str = String(utf16CodeUnits: chars, count: actualLength).lowercased()
    return str
}

private func computeCurrentKeyCodeMap() -> [UInt32: String] {
    var map = [UInt32: String]()
    for keyCode in 0 ..< 128 {
        if let str = keyCodeToString(UInt16(keyCode)) {
            map[UInt32(keyCode)] = str
        }
    }
    return map
}

@MainActor func keepCurrentKeyCodeMapUpToDate() {
    currentKeyCodeMap = computeCurrentKeyCodeMap()

    DistributedNotificationCenter.default.addObserver(
        forName: .init(kTISNotifySelectedKeyboardInputSourceChanged as String),
        object: nil,
        queue: .main,
    ) { _ in
        Task { @MainActor in
            currentKeyCodeMap = computeCurrentKeyCodeMap()
        }
    }
}
