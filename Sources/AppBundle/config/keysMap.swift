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
