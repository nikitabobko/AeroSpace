import AppKit
import Common
import Carbon

private let minus = "minus"
private let equal = "equal"

private let q = "q"
private let w = "w"
private let e = "e"
private let r = "r"
private let t = "t"
private let y = "y"
private let u = "u"
private let i = "i"
private let o = "o"
private let p = "p"
private let leftSquareBracket = "leftSquareBracket"
private let rightSquareBracket = "rightSquareBracket"
private let backslash = "backslash"
private let sectionSign = "sectionSign"

private let a = "a"
private let s = "s"
private let d = "d"
private let f = "f"
private let g = "g"
private let h = "h"
private let j = "j"
private let k = "k"
private let l = "l"
private let semicolon = "semicolon"
private let quote = "quote"

private let z = "z"
private let x = "x"
private let c = "c"
private let v = "v"
private let b = "b"
private let n = "n"
private let m = "m"
private let comma = "comma"
private let period = "period"
private let slash = "slash"

func getKeysPreset(_ layout: KeyMapping.Preset) -> [String: UInt32] {
    return switch layout {
        case .qwerty: keyNotationToKeyCode
        case .dvorak: dvorakMap
        case .colemak: colemakMap
    }
}

let keyNotationToKeyCode: [String: UInt32] = [
    sectionSign: UInt32(kVK_ISO_Section),
    "0": UInt32(kVK_ANSI_0),
    "1": UInt32(kVK_ANSI_1),
    "2": UInt32(kVK_ANSI_2),
    "3": UInt32(kVK_ANSI_3),
    "4": UInt32(kVK_ANSI_4),
    "5": UInt32(kVK_ANSI_5),
    "6": UInt32(kVK_ANSI_6),
    "7": UInt32(kVK_ANSI_7),
    "8": UInt32(kVK_ANSI_8),
    "9": UInt32(kVK_ANSI_9),
    minus: UInt32(kVK_ANSI_Minus),
    equal: UInt32(kVK_ANSI_Equal),

    q: UInt32(kVK_ANSI_Q),
    w: UInt32(kVK_ANSI_W),
    e: UInt32(kVK_ANSI_E),
    r: UInt32(kVK_ANSI_R),
    t: UInt32(kVK_ANSI_T),
    y: UInt32(kVK_ANSI_Y),
    u: UInt32(kVK_ANSI_U),
    i: UInt32(kVK_ANSI_I),
    o: UInt32(kVK_ANSI_O),
    p: UInt32(kVK_ANSI_P),
    leftSquareBracket: UInt32(kVK_ANSI_LeftBracket),
    rightSquareBracket: UInt32(kVK_ANSI_RightBracket),
    backslash: UInt32(kVK_ANSI_Backslash),

    a: UInt32(kVK_ANSI_A),
    s: UInt32(kVK_ANSI_S),
    d: UInt32(kVK_ANSI_D),
    f: UInt32(kVK_ANSI_F),
    g: UInt32(kVK_ANSI_G),
    h: UInt32(kVK_ANSI_H),
    j: UInt32(kVK_ANSI_J),
    k: UInt32(kVK_ANSI_K),
    l: UInt32(kVK_ANSI_L),
    semicolon: UInt32(kVK_ANSI_Semicolon),
    quote: UInt32(kVK_ANSI_Quote),

    z: UInt32(kVK_ANSI_Z),
    x: UInt32(kVK_ANSI_X),
    c: UInt32(kVK_ANSI_C),
    v: UInt32(kVK_ANSI_V),
    b: UInt32(kVK_ANSI_B),
    n: UInt32(kVK_ANSI_N),
    m: UInt32(kVK_ANSI_M),
    comma: UInt32(kVK_ANSI_Comma),
    period: UInt32(kVK_ANSI_Period),
    slash: UInt32(kVK_ANSI_Slash),

    "keypad0": UInt32(kVK_ANSI_Keypad0),
    "keypad1": UInt32(kVK_ANSI_Keypad1),
    "keypad2": UInt32(kVK_ANSI_Keypad2),
    "keypad3": UInt32(kVK_ANSI_Keypad3),
    "keypad4": UInt32(kVK_ANSI_Keypad4),
    "keypad5": UInt32(kVK_ANSI_Keypad5),
    "keypad6": UInt32(kVK_ANSI_Keypad6),
    "keypad7": UInt32(kVK_ANSI_Keypad7),
    "keypad8": UInt32(kVK_ANSI_Keypad8),
    "keypad9": UInt32(kVK_ANSI_Keypad9),
    "keypadClear": UInt32(kVK_ANSI_KeypadClear),
    "keypadDecimalMark": UInt32(kVK_ANSI_KeypadDecimal),
    "keypadDivide": UInt32(kVK_ANSI_KeypadDivide),
    "keypadEnter": UInt32(kVK_ANSI_KeypadEnter),
    "keypadEqual": UInt32(kVK_ANSI_KeypadEquals),
    "keypadMinus": UInt32(kVK_ANSI_KeypadMinus),
    "keypadMultiply": UInt32(kVK_ANSI_KeypadMultiply),
    "keypadPlus": UInt32(kVK_ANSI_KeypadPlus),

    "pageUp": UInt32(kVK_PageUp),
    "pageDown": UInt32(kVK_PageDown),
    "home": UInt32(kVK_Home),
    "end": UInt32(kVK_End),
    "forwardDelete": UInt32(kVK_ForwardDelete),

    "f1": UInt32(kVK_F1),
    "f2": UInt32(kVK_F2),
    "f3": UInt32(kVK_F3),
    "f4": UInt32(kVK_F4),
    "f5": UInt32(kVK_F5),
    "f6": UInt32(kVK_F6),
    "f7": UInt32(kVK_F7),
    "f8": UInt32(kVK_F8),
    "f9": UInt32(kVK_F9),
    "f10": UInt32(kVK_F10),
    "f11": UInt32(kVK_F11),
    "f12": UInt32(kVK_F12),
    "f13": UInt32(kVK_F13),
    "f14": UInt32(kVK_F14),
    "f15": UInt32(kVK_F15),
    "f16": UInt32(kVK_F16),
    "f17": UInt32(kVK_F17),
    "f18": UInt32(kVK_F18),
    "f19": UInt32(kVK_F19),
    "f20": UInt32(kVK_F20),

    "backtick": UInt32(kVK_ANSI_Grave),
    "space": UInt32(kVK_Space),
    "enter": UInt32(kVK_Return),
    "esc": UInt32(kVK_Escape),
    "backspace": UInt32(kVK_Delete),
    "tab": UInt32(kVK_Tab),

    "left": UInt32(kVK_LeftArrow),
    "down": UInt32(kVK_DownArrow),
    "up": UInt32(kVK_UpArrow),
    "right": UInt32(kVK_RightArrow),
]

private let dvorakMap: [String: UInt32] = keyNotationToKeyCode + [
    leftSquareBracket: UInt32(kVK_ANSI_Minus),
    rightSquareBracket: UInt32(kVK_ANSI_Equal),

    quote: UInt32(kVK_ANSI_Q),
    comma: UInt32(kVK_ANSI_W),
    period: UInt32(kVK_ANSI_E),
    p: UInt32(kVK_ANSI_R),
    y: UInt32(kVK_ANSI_T),
    f: UInt32(kVK_ANSI_Y),
    g: UInt32(kVK_ANSI_U),
    c: UInt32(kVK_ANSI_I),
    r: UInt32(kVK_ANSI_O),
    l: UInt32(kVK_ANSI_P),
    slash: UInt32(kVK_ANSI_LeftBracket), // leftBracket -> leftSquareBracket
    equal: UInt32(kVK_ANSI_RightBracket), // rightBracket -> rightSquareBracket
    backslash: UInt32(kVK_ANSI_Backslash),

    a: UInt32(kVK_ANSI_A),
    o: UInt32(kVK_ANSI_S),
    e: UInt32(kVK_ANSI_D),
    u: UInt32(kVK_ANSI_F),
    i: UInt32(kVK_ANSI_G),
    d: UInt32(kVK_ANSI_H),
    h: UInt32(kVK_ANSI_J),
    t: UInt32(kVK_ANSI_K),
    n: UInt32(kVK_ANSI_L),
    s: UInt32(kVK_ANSI_Semicolon),
    minus: UInt32(kVK_ANSI_Quote),

    semicolon: UInt32(kVK_ANSI_Z),
    q: UInt32(kVK_ANSI_X),
    j: UInt32(kVK_ANSI_C),
    k: UInt32(kVK_ANSI_V),
    x: UInt32(kVK_ANSI_B),
    b: UInt32(kVK_ANSI_N),
    m: UInt32(kVK_ANSI_M),
    w: UInt32(kVK_ANSI_Comma),
    v: UInt32(kVK_ANSI_Period),
    z: UInt32(kVK_ANSI_Slash),
]

private let colemakMap: [String: UInt32] = keyNotationToKeyCode + [
    q: UInt32(kVK_ANSI_Q),
    w: UInt32(kVK_ANSI_W),
    f: UInt32(kVK_ANSI_E),
    p: UInt32(kVK_ANSI_R),
    g: UInt32(kVK_ANSI_T),
    j: UInt32(kVK_ANSI_Y),
    l: UInt32(kVK_ANSI_U),
    u: UInt32(kVK_ANSI_I),
    y: UInt32(kVK_ANSI_O),
    semicolon: UInt32(kVK_ANSI_P),
    leftSquareBracket: UInt32(kVK_ANSI_LeftBracket),
    rightSquareBracket: UInt32(kVK_ANSI_RightBracket),
    backslash: UInt32(kVK_ANSI_Backslash),

    a: UInt32(kVK_ANSI_A),
    r: UInt32(kVK_ANSI_S),
    s: UInt32(kVK_ANSI_D),
    t: UInt32(kVK_ANSI_F),
    d: UInt32(kVK_ANSI_G),
    h: UInt32(kVK_ANSI_H),
    n: UInt32(kVK_ANSI_J),
    e: UInt32(kVK_ANSI_K),
    i: UInt32(kVK_ANSI_L),
    o: UInt32(kVK_ANSI_Semicolon),
    quote: UInt32(kVK_ANSI_Quote),

    z: UInt32(kVK_ANSI_Z),
    x: UInt32(kVK_ANSI_X),
    c: UInt32(kVK_ANSI_C),
    v: UInt32(kVK_ANSI_V),
    b: UInt32(kVK_ANSI_B),
    k: UInt32(kVK_ANSI_N),
    m: UInt32(kVK_ANSI_M),
    comma: UInt32(kVK_ANSI_Comma),
    period: UInt32(kVK_ANSI_Period),
    slash: UInt32(kVK_ANSI_Slash),
]

let modifiersMap: [String: CGEventFlags] = [
    "shift": .maskShift,
    "alt": .maskAlternate,
    "ctrl": .maskControl,
    "cmd": .maskCommand,
]

extension CGEventFlags {
    func toString() -> String {
        var result: [String] = []
        if contains(.maskAlternate) { result.append("alt") }
        if contains(.maskControl) { result.append("ctrl") }
        if contains(.maskCommand) { result.append("cmd") }
        if contains(.maskShift) { result.append("shift") }
        return result.joined(separator: "-")
    }
}

extension UInt32 {
    func keyCodeToString() -> String {
        switch Int(self) {
            case kVK_ANSI_A: return "a"
            case kVK_ANSI_B: return "b"
            case kVK_ANSI_C: return "c"
            case kVK_ANSI_D: return "d"
            case kVK_ANSI_E: return "e"
            case kVK_ANSI_F: return "f"
            case kVK_ANSI_G: return "g"
            case kVK_ANSI_H: return "h"
            case kVK_ANSI_I: return "i"
            case kVK_ANSI_J: return "j"
            case kVK_ANSI_K: return "k"
            case kVK_ANSI_L: return "l"
            case kVK_ANSI_M: return "m"
            case kVK_ANSI_N: return "n"
            case kVK_ANSI_O: return "o"
            case kVK_ANSI_P: return "p"
            case kVK_ANSI_Q: return "q"
            case kVK_ANSI_R: return "r"
            case kVK_ANSI_S: return "s"
            case kVK_ANSI_T: return "t"
            case kVK_ANSI_U: return "u"
            case kVK_ANSI_V: return "v"
            case kVK_ANSI_W: return "w"
            case kVK_ANSI_X: return "x"
            case kVK_ANSI_Y: return "y"
            case kVK_ANSI_Z: return "z"

            case kVK_ANSI_0: return "0"
            case kVK_ANSI_1: return "1"
            case kVK_ANSI_2: return "2"
            case kVK_ANSI_3: return "3"
            case kVK_ANSI_4: return "4"
            case kVK_ANSI_5: return "5"
            case kVK_ANSI_6: return "6"
            case kVK_ANSI_7: return "7"
            case kVK_ANSI_8: return "8"
            case kVK_ANSI_9: return "9"

            case kVK_ANSI_Period: return "period"
            case kVK_ANSI_Quote: return "quote"
            case kVK_ANSI_LeftBracket: return "leftSquareBracket"
            case kVK_ANSI_RightBracket: return "rightSquareBracket"
            case kVK_ANSI_Semicolon: return "semicolon"
            case kVK_ANSI_Slash: return "slash"
            case kVK_ANSI_Backslash: return "backslash"
            case kVK_ANSI_Comma: return "comma"
            case kVK_ANSI_Equal: return "equal"
            case kVK_ANSI_Grave: return "backtick"
            case kVK_ANSI_Minus: return "minus"
            case kVK_Space: return "space"
            case kVK_Tab: return "tab"
            case kVK_Return: return "enter"
            case kVK_PageUp: return "pageUp"
            case kVK_PageDown: return "pageDown"
            case kVK_Home: return "home"
            case kVK_End: return "end"
            case kVK_LeftArrow: return "left"
            case kVK_DownArrow: return "down"
            case kVK_UpArrow: return "up"
            case kVK_RightArrow: return "right"
            case kVK_Escape: return "esc"
            case kVK_Delete: return "backspace"
            case kVK_ISO_Section: return "sectionSign"

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
            case kVK_F20: return "f20"

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
            case kVK_ANSI_KeypadClear: return "keypadClear"
            case kVK_ANSI_KeypadDecimal: return "keypadDecimalMark"
            case kVK_ANSI_KeypadDivide: return "keypadDivide"
            case kVK_ANSI_KeypadEnter: return "keypadEnter"
            case kVK_ANSI_KeypadEquals: return "keypadEqual"
            case kVK_ANSI_KeypadMinus: return "keypadMinus"
            case kVK_ANSI_KeypadMultiply: return "keypadMultiply"
            case kVK_ANSI_KeypadPlus: return "keypadPlus"

            case kVK_ForwardDelete: return "forwardDelete"
            case kVK_Help: return "help"
            case kVK_VolumeUp: return "volumeUp"
            case kVK_VolumeDown: return "volumeDown"
            case kVK_Mute: return "mute"

            default: return "unknown"
        }
    }
}
