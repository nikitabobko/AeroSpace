import AppKit
import HotKey
import Common

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

func getKeysPreset(_ layout: KeyMapping.Preset) -> [String: Key] {
    switch layout {
    case .qwerty:
        return keyNotationToKeyCode
    case .dvorak:
        return dvorakMap
    }
}

let keyNotationToKeyCode: [String: Key] = [
    minus: .minus,
    equal: .equal,

    q: .q,
    w: .w,
    e: .e,
    r: .r,
    t: .t,
    y: .y,
    u: .u,
    i: .i,
    o: .o,
    p: .p,
    leftSquareBracket: .leftBracket,
    rightSquareBracket: .rightBracket,
    backslash: .backslash,

    a: .a,
    s: .s,
    d: .d,
    f: .f,
    g: .g,
    h: .h,
    j: .j,
    k: .k,
    l: .l,
    semicolon: .semicolon,
    quote: .quote,

    z: .z,
    x: .x,
    c: .c,
    v: .v,
    b: .b,
    n: .n,
    m: .m,
    comma: .comma,
    period: .period,
    slash: .slash,

    "0": .zero,
    "1": .one,
    "2": .two,
    "3": .three,
    "4": .four,
    "5": .five,
    "6": .six,
    "7": .seven,
    "8": .eight,
    "9": .nine,

    "keypad0": .keypad0,
    "keypad1": .keypad1,
    "keypad2": .keypad2,
    "keypad3": .keypad3,
    "keypad4": .keypad4,
    "keypad5": .keypad5,
    "keypad6": .keypad6,
    "keypad7": .keypad7,
    "keypad8": .keypad8,
    "keypad9": .keypad9,
    "keypadClear": .keypadClear,
    "keypadDecimalMark": .keypadDecimal,
    "keypadDivide": .keypadDivide,
    "keypadEnter": .keypadEnter,
    "keypadEqual": .keypadEquals,
    "keypadMinus": .keypadMinus,
    "keypadMultiply": .keypadMultiply,
    "keypadPlus": .keypadPlus,

    "f1": .f1,
    "f2": .f2,
    "f3": .f3,
    "f4": .f4,
    "f5": .f5,
    "f6": .f6,
    "f7": .f7,
    "f8": .f8,
    "f9": .f9,
    "f10": .f10,
    "f11": .f11,
    "f12": .f12,
    "f13": .f13,
    "f14": .f14,
    "f15": .f15,
    "f16": .f16,
    "f17": .f17,
    "f18": .f18,
    "f19": .f19,
    "f20": .f20,

    "backtick": .grave,
    "space": .space,
    "enter": .return,
    "esc": .escape,
    "backspace": .delete,
    "tab": .tab,

    "left": .leftArrow,
    "down": .downArrow,
    "up": .upArrow,
    "right": .rightArrow,
]

private let dvorakMap: [String: Key] = keyNotationToKeyCode + [
    leftSquareBracket: .minus,
    rightSquareBracket: .equal,

    quote: .q,
    comma: .w,
    period: .e,
    p: .r,
    y: .t,
    f: .y,
    g: .u,
    c: .i,
    r: .o,
    l: .p,
    slash: .leftBracket,
    equal: .rightBracket,
    backslash: .backslash,

    a: .a,
    o: .s,
    e: .d,
    u: .f,
    i: .g,
    d: .h,
    h: .j,
    t: .k,
    n: .l,
    s: .semicolon,
    minus: .quote,

    semicolon: .z,
    q: .x,
    j: .c,
    k: .v,
    x: .b,
    b: .n,
    m: .m,
    w: .comma,
    v: .period,
    z: .slash,
]

let modifiersMap: [String: NSEvent.ModifierFlags] = [
    "shift": .shift,
    "alt": .option,
    "ctrl": .control,
    "cmd": .command,
]

extension NSEvent.ModifierFlags {
    func toString() -> String {
        var result: [String] = []
        if contains(.option) { result.append("alt") }
        if contains(.control) { result.append("ctrl") }
        if contains(.command) { result.append("cmd") }
        if contains(.shift) { result.append("shift") }
        return result.joined(separator: "-")
    }
}

// doesn't work :(
//extension NSEvent.ModifierFlags {
//    static let lOption = NSEvent.ModifierFlags(rawValue: 1 << 1)
//    static let rOption = NSEvent.ModifierFlags(rawValue: 1 << 2)
//    static let lShift = NSEvent.ModifierFlags(rawValue: 0x00000002)
//    static let rShift = NSEvent.ModifierFlags(rawValue: 0x00000004)
//    static let lCommand = NSEvent.ModifierFlags(rawValue: 1 << 7)
//    static let rCommand = NSEvent.ModifierFlags(rawValue: 0x00000010)
//}

// NSEvent.ModifierFlags.command.rawValue // 1 << 20
// NSEvent.ModifierFlags.option.rawValue // 1 << 19
// NSEvent.ModifierFlags.control.rawValue // 1 << 18
// NSEvent.ModifierFlags.shift.rawValue // 1 << 17
// https://github.com/koekeishiya/skhd/blob/master/src/hotkey.h
