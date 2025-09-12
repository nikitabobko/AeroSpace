import Carbon
import Foundation

// This file is a Swift translation of the Objective-C code provided by the user.
// It translates a keycode to a string, taking the current keyboard layout into account.
func keycodeToString(_ keyCode: UInt16) -> String? {
    // Handle special keys first.
    switch Int(keyCode) {
        case kVK_F1: return "f1"
        case kVK_F2: return "f2"
        case kVK_F3: return "f3"
        case kVK_F4: return "f4"
        case kVK_F5: return "f5"
        case kVK_F6: return "f6"
        case kVK_F7: return "f7"
        case kVK_F8: return "f8"
        case kVK_F9: return "f9"
        case kVK_F10: return "f10"
        case kVK_F11: return "f11"
        case kVK_F12: return "f12"
        case kVK_F13: return "f13"
        case kVK_F14: return "f14"
        case kVK_F15: return "f15"
        case kVK_F16: return "f16"
        case kVK_F17: return "f17"
        case kVK_F18: return "f18"
        case kVK_F19: return "f19"
        case kVK_Space: return "space"
        case kVK_Escape: return "esc"
        case kVK_Delete: return "backspace"
        case kVK_ForwardDelete: return "forwardDelete"
        case kVK_LeftArrow: return "left"
        case kVK_RightArrow: return "right"
        case kVK_UpArrow: return "up"
        case kVK_DownArrow: return "down"
        case kVK_Help: return "help"
        case kVK_Home: return "home"
        case kVK_End: return "end"
        case kVK_PageUp: return "pageUp"
        case kVK_PageDown: return "pageDown"
        case kVK_Tab: return "tab"
        case kVK_Return: return "enter"

        // Keypad
        case kVK_ANSI_Keypad0: return "keypad0"
        case kVK_ANSI_Keypad1: return "keypad1"
        case kVK_ANSI_Keypad2: return "keypad2"
        case kVK_ANSI_Keypad3: return "keypad3"
        case kVK_ANSI_Keypad4: return "keypad4"
        case kVK_ANSI_Keypad5: return "keypad5"
        case kVK_ANSI_Keypad6: return "keypad6"
        case kVK_ANSI_Keypad7: return "keypad7"
        case kVK_ANSI_Keypad8: return "keypad8"
        case kVK_ANSI_Keypad9: return "keypad9"
        case kVK_ANSI_KeypadDecimal: return "keypadDecimalMark"
        case kVK_ANSI_KeypadMultiply: return "keypadMultiply"
        case kVK_ANSI_KeypadPlus: return "keypadPlus"
        case kVK_ANSI_KeypadClear: return "keypadClear"
        case kVK_ANSI_KeypadDivide: return "keypadDivide"
        case kVK_ANSI_KeypadEnter: return "keypadEnter"
        case kVK_ANSI_KeypadMinus: return "keypadMinus"
        case kVK_ANSI_KeypadEquals: return "keypadEqual"
        default: break
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
    return switch str {
        case ".": "period"
        case ",": "comma"
        case "[": "leftSquareBracket"
        case "]": "rightSquareBracket"
        case "/": "slash"
        case "\\": "backslash"
        case "-": "minus"
        case "=": "equal"
        case "'": "quote"
        case "`": "backtick"
        case ";": "semicolon"
        case "§": "sectionSign"
        default: str
    }
}
