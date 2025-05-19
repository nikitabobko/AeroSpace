import AppKit
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

// Define virtual key codes (subset, expand as needed based on keyNotationToKeyCode)
enum VirtualKeyCodes {  // Using an enum namespace for clarity
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let d: UInt16 = 0x02
    static let f: UInt16 = 0x03
    static let h: UInt16 = 0x04
    static let g: UInt16 = 0x05
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    // sectionSign for ISO layout
    static let section: UInt16 = 0x0A  // Or grave for ANSI on some mappings
    static let b: UInt16 = 0x0B
    static let q: UInt16 = 0x0C
    static let w: UInt16 = 0x0D
    static let e: UInt16 = 0x0E
    static let r: UInt16 = 0x0F
    static let y: UInt16 = 0x10
    static let t: UInt16 = 0x11
    static let _1: UInt16 = 0x12
    static let _2: UInt16 = 0x13
    static let _3: UInt16 = 0x14
    static let _4: UInt16 = 0x15
    static let _6: UInt16 = 0x16
    static let _5: UInt16 = 0x17
    static let equal: UInt16 = 0x18
    static let _9: UInt16 = 0x19
    static let _7: UInt16 = 0x1A
    static let minus: UInt16 = 0x1B
    static let _8: UInt16 = 0x1C
    static let _0: UInt16 = 0x1D
    static let rightBracket: UInt16 = 0x1E  // ]
    static let o: UInt16 = 0x1F
    static let u: UInt16 = 0x20
    static let leftBracket: UInt16 = 0x21  // [
    static let i: UInt16 = 0x22
    static let p: UInt16 = 0x23
    static let enter: UInt16 = 0x24  // Primary Enter/Return
    static let l: UInt16 = 0x25
    static let j: UInt16 = 0x26
    static let quote: UInt16 = 0x27  // '
    static let k: UInt16 = 0x28
    static let semicolon: UInt16 = 0x29  // ;
    static let backslash: UInt16 = 0x2A  // \
    static let comma: UInt16 = 0x2B  // ,
    static let slash: UInt16 = 0x2C  // /
    static let n: UInt16 = 0x2D
    static let m: UInt16 = 0x2E
    static let period: UInt16 = 0x2F  // .
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    static let grave: UInt16 = 0x32  // ` / ~ (ANSI) , or § / ± (ISO)
    // For sectionSign, some use 0x0A. Let's stick to 0x32 for grave/backtick common on ANSI
    // and handle sectionSign separately if needed via specific mapping.
    static let backspace: UInt16 = 0x33  // Delete (Backspace)
    // static let enterPowerbook: UInt16 = 0x34 // Less common
    static let escape: UInt16 = 0x35
    // Modifier key codes are handled by physicalModifierKeyToKeyCode

    static let keypadDecimal: UInt16 = 0x41
    static let keypadMultiply: UInt16 = 0x43
    static let keypadPlus: UInt16 = 0x45
    static let keypadClear: UInt16 = 0x47  // Num Lock on some
    static let keypadDivide: UInt16 = 0x4B
    static let keypadEnter: UInt16 = 0x4C
    static let keypadMinus: UInt16 = 0x4E
    static let keypadEquals: UInt16 = 0x51
    static let keypad0: UInt16 = 0x52
    static let keypad1: UInt16 = 0x53
    static let keypad2: UInt16 = 0x54
    static let keypad3: UInt16 = 0x55
    static let keypad4: UInt16 = 0x56
    static let keypad5: UInt16 = 0x57
    static let keypad6: UInt16 = 0x58
    static let keypad7: UInt16 = 0x59
    static let keypad8: UInt16 = 0x5B
    static let keypad9: UInt16 = 0x5C

    static let f1: UInt16 = 0x7A
    static let f2: UInt16 = 0x78
    static let f3: UInt16 = 0x63
    static let f4: UInt16 = 0x76
    static let f5: UInt16 = 0x60
    static let f6: UInt16 = 0x61
    static let f7: UInt16 = 0x62
    static let f8: UInt16 = 0x64
    static let f9: UInt16 = 0x65
    static let f10: UInt16 = 0x6D
    static let f11: UInt16 = 0x67
    static let f12: UInt16 = 0x6F
    static let f13: UInt16 = 0x69
    static let f14: UInt16 = 0x6B
    static let f15: UInt16 = 0x71
    static let f16: UInt16 = 0x6A
    static let f17: UInt16 = 0x40
    static let f18: UInt16 = 0x4F
    static let f19: UInt16 = 0x50
    static let f20: UInt16 = 0x5A

    static let home: UInt16 = 0x73
    static let pageUp: UInt16 = 0x74
    static let forwardDelete: UInt16 = 0x75  // Del key below Help
    static let end: UInt16 = 0x77
    static let pageDown: UInt16 = 0x79

    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
    // Help/Insert is 0x72, but often remapped
}

func getKeysPreset(_ layout: KeyMapping.Preset) -> [String: UInt16] {
    return switch layout {
        case .qwerty: keyNotationToVirtualKeyCode
        case .dvorak: dvorakMap
        case .colemak: colemakMap
    }
}

let keyNotationToVirtualKeyCode: [String: UInt16] = [
    sectionSign: VirtualKeyCodes.section,
    "0": VirtualKeyCodes._0,
    "1": VirtualKeyCodes._1,
    "2": VirtualKeyCodes._2,
    "3": VirtualKeyCodes._3,
    "4": VirtualKeyCodes._4,
    "5": VirtualKeyCodes._5,
    "6": VirtualKeyCodes._6,
    "7": VirtualKeyCodes._7,
    "8": VirtualKeyCodes._8,
    "9": VirtualKeyCodes._9,
    minus: VirtualKeyCodes.minus,
    equal: VirtualKeyCodes.equal,

    q: VirtualKeyCodes.q,
    w: VirtualKeyCodes.w,
    e: VirtualKeyCodes.e,
    r: VirtualKeyCodes.r,
    t: VirtualKeyCodes.t,
    y: VirtualKeyCodes.y,
    u: VirtualKeyCodes.u,
    i: VirtualKeyCodes.i,
    o: VirtualKeyCodes.o,
    p: VirtualKeyCodes.p,
    leftSquareBracket: VirtualKeyCodes.leftBracket,
    rightSquareBracket: VirtualKeyCodes.rightBracket,
    backslash: VirtualKeyCodes.backslash,

    a: VirtualKeyCodes.a,
    s: VirtualKeyCodes.s,
    d: VirtualKeyCodes.d,
    f: VirtualKeyCodes.f,
    g: VirtualKeyCodes.g,
    h: VirtualKeyCodes.h,
    j: VirtualKeyCodes.j,
    k: VirtualKeyCodes.k,
    l: VirtualKeyCodes.l,
    semicolon: VirtualKeyCodes.semicolon,
    quote: VirtualKeyCodes.quote,

    z: VirtualKeyCodes.z,
    x: VirtualKeyCodes.x,
    c: VirtualKeyCodes.c,
    v: VirtualKeyCodes.v,
    b: VirtualKeyCodes.b,
    n: VirtualKeyCodes.n,
    m: VirtualKeyCodes.m,
    comma: VirtualKeyCodes.comma,
    period: VirtualKeyCodes.period,
    slash: VirtualKeyCodes.slash,

    "keypad0": VirtualKeyCodes.keypad0,
    "keypad1": VirtualKeyCodes.keypad1,
    "keypad2": VirtualKeyCodes.keypad2,
    "keypad3": VirtualKeyCodes.keypad3,
    "keypad4": VirtualKeyCodes.keypad4,
    "keypad5": VirtualKeyCodes.keypad5,
    "keypad6": VirtualKeyCodes.keypad6,
    "keypad7": VirtualKeyCodes.keypad7,
    "keypad8": VirtualKeyCodes.keypad8,
    "keypad9": VirtualKeyCodes.keypad9,
    "keypadClear": VirtualKeyCodes.keypadClear,
    "keypadDecimalMark": VirtualKeyCodes.keypadDecimal,
    "keypadDivide": VirtualKeyCodes.keypadDivide,
    "keypadEnter": VirtualKeyCodes.keypadEnter,
    "keypadEqual": VirtualKeyCodes.keypadEquals,
    "keypadMinus": VirtualKeyCodes.keypadMinus,
    "keypadMultiply": VirtualKeyCodes.keypadMultiply,
    "keypadPlus": VirtualKeyCodes.keypadPlus,

    "pageUp": VirtualKeyCodes.pageUp,
    "pageDown": VirtualKeyCodes.pageDown,
    "home": VirtualKeyCodes.home,
    "end": VirtualKeyCodes.end,
    "forwardDelete": VirtualKeyCodes.forwardDelete,

    "f1": VirtualKeyCodes.f1,
    "f2": VirtualKeyCodes.f2,
    "f3": VirtualKeyCodes.f3,
    "f4": VirtualKeyCodes.f4,
    "f5": VirtualKeyCodes.f5,
    "f6": VirtualKeyCodes.f6,
    "f7": VirtualKeyCodes.f7,
    "f8": VirtualKeyCodes.f8,
    "f9": VirtualKeyCodes.f9,
    "f10": VirtualKeyCodes.f10,
    "f11": VirtualKeyCodes.f11,
    "f12": VirtualKeyCodes.f12,
    "f13": VirtualKeyCodes.f13,
    "f14": VirtualKeyCodes.f14,
    "f15": VirtualKeyCodes.f15,
    "f16": VirtualKeyCodes.f16,
    "f17": VirtualKeyCodes.f17,
    "f18": VirtualKeyCodes.f18,
    "f19": VirtualKeyCodes.f19,
    "f20": VirtualKeyCodes.f20,

    "backtick": VirtualKeyCodes.grave,  // For ANSI layout, grave is 0x32. Section sign is 0x0A for ISO.
    // The original HotKey.Key.grave might map to 0x32 (kVK_ANSI_Grave)
    // HotKey.Key.section maps to 0x0A (kVK_ISO_Section)
    // For simplicity, "backtick" maps to ANSI grave. "sectionSign" handles ISO.
    "space": VirtualKeyCodes.space,
    "enter": VirtualKeyCodes.enter,
    "esc": VirtualKeyCodes.escape,
    "backspace": VirtualKeyCodes.backspace,
    "tab": VirtualKeyCodes.tab,

    "left": VirtualKeyCodes.leftArrow,
    "down": VirtualKeyCodes.downArrow,
    "up": VirtualKeyCodes.upArrow,
    "right": VirtualKeyCodes.rightArrow,
]

private let dvorakMap: [String: UInt16] =
    keyNotationToVirtualKeyCode + [
        leftSquareBracket: VirtualKeyCodes.minus,
        rightSquareBracket: VirtualKeyCodes.equal,

        quote: VirtualKeyCodes.q,
        comma: VirtualKeyCodes.w,
        period: VirtualKeyCodes.e,
        p: VirtualKeyCodes.r,
        y: VirtualKeyCodes.t,
        f: VirtualKeyCodes.y,
        g: VirtualKeyCodes.u,
        c: VirtualKeyCodes.i,
        r: VirtualKeyCodes.o,
        l: VirtualKeyCodes.p,
        slash: VirtualKeyCodes.leftBracket,
        equal: VirtualKeyCodes.rightBracket,
        backslash: VirtualKeyCodes.backslash,

        a: VirtualKeyCodes.a,
        o: VirtualKeyCodes.s,
        e: VirtualKeyCodes.d,
        u: VirtualKeyCodes.f,
        i: VirtualKeyCodes.g,
        d: VirtualKeyCodes.h,
        h: VirtualKeyCodes.j,
        t: VirtualKeyCodes.k,
        n: VirtualKeyCodes.l,
        s: VirtualKeyCodes.semicolon,
        minus: VirtualKeyCodes.quote,

        semicolon: VirtualKeyCodes.z,
        q: VirtualKeyCodes.x,
        j: VirtualKeyCodes.c,
        k: VirtualKeyCodes.v,
        x: VirtualKeyCodes.b,
        b: VirtualKeyCodes.n,
        w: VirtualKeyCodes.comma,
        v: VirtualKeyCodes.period,
        z: VirtualKeyCodes.slash,
    ]

private let colemakMap: [String: UInt16] =
    keyNotationToVirtualKeyCode + [
        f: VirtualKeyCodes.e,
        p: VirtualKeyCodes.r,
        g: VirtualKeyCodes.t,
        j: VirtualKeyCodes.y,
        l: VirtualKeyCodes.u,
        u: VirtualKeyCodes.i,
        y: VirtualKeyCodes.o,
        semicolon: VirtualKeyCodes.p,
        r: VirtualKeyCodes.s,
        s: VirtualKeyCodes.d,
        t: VirtualKeyCodes.f,
        d: VirtualKeyCodes.g,
        n: VirtualKeyCodes.j,
        e: VirtualKeyCodes.k,
        i: VirtualKeyCodes.l,
        o: VirtualKeyCodes.semicolon,
        k: VirtualKeyCodes.n,
    ]

// Dead code - this map was for the old NSEvent.ModifierFlags based system.
// The new system uses PhysicalModifierKey and GenericModifierType.
// let modifiersMap: [String: NSEvent.ModifierFlags] = [
//     "shift": .shift,
//     "alt": .option,
//     "ctrl": .control,
//     "cmd": .command,
// ]

// Added for specific modifier key handling
enum PhysicalModifierKey: String, CaseIterable, Hashable, Sendable {
    case leftShift, rightShift, leftControl, rightControl, leftOption, rightOption, leftCommand,
         rightCommand, function

    // Helper to get the string representation used in config files
    var configKey: String {
        switch self {
            case .leftShift: "lshift"
            case .rightShift: "rshift"
            case .leftControl: "lctrl"
            case .rightControl: "rctrl"
            case .leftOption: "lalt"
            case .rightOption: "ralt"
            case .leftCommand: "lcmd"
            case .rightCommand: "rcmd"
            case .function: "fn"
        }
    }
}

// Explicitly define the map with all keys for robustness, especially in test environments
let specificModifiersMap: [String: PhysicalModifierKey] = [
    // Specific left/right
    PhysicalModifierKey.leftShift.configKey: .leftShift,
    PhysicalModifierKey.rightShift.configKey: .rightShift,
    PhysicalModifierKey.leftControl.configKey: .leftControl,
    PhysicalModifierKey.rightControl.configKey: .rightControl,
    PhysicalModifierKey.leftOption.configKey: .leftOption,
    PhysicalModifierKey.rightOption.configKey: .rightOption,
    PhysicalModifierKey.leftCommand.configKey: .leftCommand,
    PhysicalModifierKey.rightCommand.configKey: .rightCommand,
    PhysicalModifierKey.function.configKey: .function,
]

// New: For generic modifier parsing
enum GenericModifierType: String, CaseIterable, Hashable, Sendable {
    case option, command, control, shift
}

let genericModifiersMap: [String: GenericModifierType] = [
    "alt": .option, "option": .option,
    "cmd": .command, "command": .command,
    "ctrl": .control, "control": .control,
    "shift": .shift,
]

let physicalModifierKeyToKeyCode: [PhysicalModifierKey: UInt16] = [
    .leftShift: 0x38, .rightShift: 0x3C,
    .leftControl: 0x3B, .rightControl: 0x3E,
    .leftOption: 0x3A, .rightOption: 0x3D,
    .leftCommand: 0x37, .rightCommand: 0x36,
    .function: 0x3F,
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

extension Set<PhysicalModifierKey> {
    func toString() -> String {
        // Sort to ensure consistent order for descriptions, e.g., cmd-ctrl-shift
        self.sorted(by: { $0.configKey < $1.configKey }).map { $0.configKey }.joined(separator: "-")
    }
}

// New: Map virtual key code back to string for descriptions (optional, can be expanded)
func virtualKeyCodeToString(_ keyCode: UInt16) -> String {
    // This is the reverse of keyNotationToVirtualKeyCode for common keys
    // Could be generated or manually maintained for important keys
    // For simplicity, we can find the first key in keyNotationToVirtualKeyCode that maps to this keyCode
    if let keyName = keyNotationToVirtualKeyCode.first(where: { $0.value == keyCode })?.key {
        return keyName
    }
    // Fallback for less common keys or if not in the map
    switch keyCode {
        case VirtualKeyCodes.a: return "a"
        // ... add more cases as needed for complete coverage for descriptions
        default: return "keyCode_0x" + String(keyCode, radix: 16)
    }
}

// Extension moved from GlobalHotkeyMonitor.swift
// This makes the utility available to any other component that needs it.
extension PhysicalModifierKey {
    var genericType: GenericModifierType? {
        switch self {
            case .leftOption, .rightOption: return .option
            case .leftCommand, .rightCommand: return .command
            case .leftControl, .rightControl: return .control
            case .leftShift, .rightShift: return .shift
            case .function: return nil  // Fn is always specific
        }
    }
}
