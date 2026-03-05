import AppKit
import Common
import Foundation
import TOMLKit

@MainActor private var keyboardMonitor: KeyboardMonitor?
@MainActor private var hotkeys: [ExpandedHotkey: () -> Void] = [:]

@MainActor func resetHotKeys() {
    hotkeys = [:]
    keyboardMonitor = KeyboardMonitor() { event in
        let modifiersMask = CGEventFlags([
            .maskShiftL, .maskShiftR,
            .maskControlL, .maskControlR,
            .maskAlternateL, .maskAlternateR,
            .maskCommandL, .maskCommandR,
            .maskSecondaryFn,
        ])
        let modifiers = event.flags.intersection(modifiersMask)

        let hotkey: ExpandedHotkey
        switch config.keyMapping.matchKeyEventBy {
            case .keyCode:
                hotkey = ExpandedHotkey(modifiers: modifiers, key: .keyCode(event.keyCode, symbol: nil))
            case .keySymbol:
                guard let symbol = currentKeyCodeMap[event.keyCode] else {
                    return false
                }
                hotkey = ExpandedHotkey(modifiers: modifiers, key: .symbol(symbol))
        }

        guard let handler = hotkeys[hotkey] else {
            return false
        }

        handler()
        return true
    }
}

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) async throws {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? []
    hotkeys.removeAll(keepingCapacity: true)

    for binding in targetBindings {
        let action: () -> Void = {
            Task {
                try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
                    _ = try await binding.commands.runCmdSeq(.defaultEnv, .emptyStdin)
                }
            }
        }

        binding.hotkey.expanded.forEach { hotkey in
            hotkeys[hotkey] = action
        }
    }
    let oldMode = activeMode
    activeMode = targetMode
    if oldMode != targetMode && !config.onModeChanged.isEmpty {
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.onModeChanged, token) {
            _ = try await config.onModeChanged.runCmdSeq(.defaultEnv, .emptyStdin)
        }
    }
}

extension CGEventFlags {
    static let maskShiftL = CGEventFlags.maskShift.union(CGEventFlags(rawValue: 1 << 1))
    static let maskShiftR = CGEventFlags.maskShift.union(CGEventFlags(rawValue: 1 << 2))
    static let maskControlL = CGEventFlags.maskControl.union(CGEventFlags(rawValue: 1 << 0))
    static let maskControlR = CGEventFlags.maskControl.union(CGEventFlags(rawValue: 1 << 13))
    static let maskAlternateL = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: 1 << 5))
    static let maskAlternateR = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: 1 << 6))
    static let maskCommandL = CGEventFlags.maskCommand.union(CGEventFlags(rawValue: 1 << 3))
    static let maskCommandR = CGEventFlags.maskCommand.union(CGEventFlags(rawValue: 1 << 4))

    /// Expand any non-positional modifier flags (like shift, or alt), to all directional combinations (i.e. lshift, rshift, lalt, ralt, ...).
    func expandVariants() -> [CGEventFlags] {
        let base = self.subtracting(CGEventFlags([
            .maskShiftL, .maskShiftR,
            .maskControlL, .maskControlR,
            .maskAlternateL, .maskAlternateR,
            .maskCommandL, .maskCommandR,
        ]))

        var variants: [CGEventFlags] = [base]

        func expand(current: [CGEventFlags], left: CGEventFlags, right: CGEventFlags, either: CGEventFlags) -> [CGEventFlags] {
            if contains(left) { return current.map { $0.union(left) } }
            if contains(right) { return current.map { $0.union(right) } }
            if contains(either) {
                return current.flatMap { base in
                    [base.union(left), base.union(right)]
                }
            }
            return current
        }

        variants = expand(current: variants, left: .maskShiftL, right: .maskShiftR, either: .maskShift)
        variants = expand(current: variants, left: .maskControlL, right: .maskControlR, either: .maskControl)
        variants = expand(current: variants, left: .maskAlternateL, right: .maskAlternateR, either: .maskAlternate)
        variants = expand(current: variants, left: .maskCommandL, right: .maskCommandR, either: .maskCommand)

        return variants
    }

    func toString() -> String {
        var result: [String] = []

        if contains(.maskControlL) { result.append("lctrl") }
        else if contains(.maskControlR) { result.append("rctrl") }
        else if contains(.maskControl) { result.append("ctrl") }

        if contains(.maskSecondaryFn) { result.append("fn") }

        if contains(.maskAlternateL) { result.append("lalt") }
        else if contains(.maskAlternateR) { result.append("ralt") }
        else if contains(.maskAlternate) { result.append("alt") }

        if contains(.maskShiftL) { result.append("lshift") }
        else if contains(.maskShiftR) { result.append("rshift") }
        else if contains(.maskShift) { result.append("shift") }

        if contains(.maskCommandL) { result.append("lcmd") }
        else if contains(.maskCommandR) { result.append("rcmd") }
        else if contains(.maskCommand) { result.append("cmd") }

        return result.joined(separator: "-")
    }
}

private let modifiersMap: [String: CGEventFlags] = [
    "shift": .maskShift,
    "lshift": .maskShiftL,
    "rshift": .maskShiftR,

    "alt": .maskAlternate,
    "lalt": .maskAlternateL,
    "ralt": .maskAlternateR,

    "ctrl": .maskControl,
    "lctrl": .maskControlL,
    "rctrl": .maskControlR,

    "cmd": .maskCommand,
    "lcmd": .maskCommandL,
    "rcmd": .maskCommandR,

    "fn": .maskSecondaryFn,
]

private let keyNames: [String: String] = [
    "period": ".",
    "comma": ",",
    "leftSquareBracket": "[",
    "rightSquareBracket": "]",
    "slash": "/",
    "backslash": "\\",
    "minus": "-",
    "equal": "=",
    "quote": "'",
    "backtick": "`",
    "semicolon": ";",
    "sectionSign": "§",
]

enum KeyMatch: Equatable, Hashable {
    case keyCode(UInt32, symbol: String?)
    case symbol(String)

    var symbol: String {
        switch self {
            case .keyCode(let keyCode, let symbol):
                if let symbol {
                    return symbol
                }
                return "<\(keyCode)>"
            case .symbol(let symbol):
                return symbol
        }
    }

    static func == (lhs: KeyMatch, rhs: KeyMatch) -> Bool {
        switch (lhs, rhs) {
            case (.keyCode(let lhsCode, _), .keyCode(let rhsCode, _)):
                lhsCode == rhsCode
            case (.symbol(let lhsSymbol), .symbol(let rhsSymbol)):
                lhsSymbol == rhsSymbol
            default:
                false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case .keyCode(let code, _):
                hasher.combine(0)
                hasher.combine(code)
            case .symbol(let symbol):
                hasher.combine(1)
                hasher.combine(symbol)
        }
    }
}

struct Hotkey: Equatable, Sendable {
    let modifiers: CGEventFlags
    let key: KeyMatch
    let description: String
    let expanded: [ExpandedHotkey]

    init(modifiers: CGEventFlags, key: KeyMatch) {
        self.modifiers = modifiers
        self.key = key
        self.description = modifiers.isEmpty
            ? key.symbol
            : modifiers.toString() + "-" + key.symbol

        self.expanded = modifiers
            .expandVariants()
            .map {
                ExpandedHotkey(modifiers: $0, key: key)
            }
    }
}

struct ExpandedHotkey: Hashable, Sendable {
    let modifiers: CGEventFlags
    let key: KeyMatch

    func hash(into hasher: inout Hasher) {
        hasher.combine(modifiers.rawValue)
        hasher.combine(key)
    }
}

struct HotkeyBinding: Equatable, Sendable {
    let hotkey: Hotkey
    let commands: [any Command]

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.hotkey == rhs.hotkey &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: KeyMapping) -> [HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return []
    }
    var existingHotkeys = Set<ExpandedHotkey>()
    var result: [HotkeyBinding] = []
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .flatMap { hotkey -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
                    HotkeyBinding(hotkey: hotkey, commands: $0)
                }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if !existingHotkeys.isDisjoint(with: binding.hotkey.expanded) {
                errors.append(.semantic(backtrace, "'\(binding.hotkey.description)' Binding redeclaration"))
            }
            existingHotkeys.formUnion(binding.hotkey.expanded)
            result.append(binding)
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: KeyMapping) -> ParsedToml<Hotkey> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<CGEventFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { CGEventFlags($0) }

    let key: KeyMatch? = switch mapping.matchKeyEventBy {
        case .keyCode:
            rawKeys.last
                .flatMap { symbol in
                    let symbol = String(symbol)
                    if let keyCode = mapping.resolve(symbol) {
                        return KeyMatch.keyCode(keyCode, symbol: symbol)
                    }
                    return nil
                }
        case .keySymbol:
            rawKeys.last
                .flatMap { symbol in
                    let symbol = String(symbol)
                    if baseKeyCodeMap.values.contains(symbol) {
                        return .symbol(symbol)
                    }
                    if let symbol = keyNames[symbol] {
                        return .symbol(symbol)
                    }
                    if symbol.count == 1 {
                        return .symbol(symbol)
                    }

                    return nil
                }
    }

    return modifiers.flatMap { modifiers -> ParsedToml<Hotkey> in
        key
            .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
            .flatMap { key -> ParsedToml<Hotkey> in
                .success(Hotkey(modifiers: modifiers, key: key))
            }
    }
}
