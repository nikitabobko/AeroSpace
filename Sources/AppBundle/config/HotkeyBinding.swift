import AppKit
import Common
import Foundation
import TOMLKit

@MainActor private var keyboardMonitor: KeyboardMonitor?
@MainActor private var hotkeys: [Hotkey: () -> Void] = [:]

@MainActor func resetHotKeys() {
    hotkeys = [:]
    keyboardMonitor = KeyboardMonitor() { event in
        guard let key = currentKeyCodeMap[event.keyCode] else {
            return false
        }

        let hotkey = Hotkey(modifiers: event.flags, key: key)
        guard let handler = hotkeys[hotkey] else {
            return false
        }

        handler()
        return true
    }
}

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    hotkeys.removeAll(keepingCapacity: true)

    for binding in targetBindings.values {
        hotkeys[binding.hotkey] = {
            Task {
                if let activeMode {
                    try await runSession(.hotkeyBinding, .checkServerIsEnabledOrDie) { () throws in
                        _ = try await config.modes[activeMode]?.bindings[binding.hotkey]?.commands
                            .runCmdSeq(.defaultEnv, .emptyStdin)
                    }
                }
            }
        }
    }

    activeMode = targetMode
}

extension CGEventFlags {
    func toString() -> String {
        var result: [String] = []
        if contains(.maskControl) { result.append("ctrl") }
        if contains(.maskAlternate) { result.append("alt") }
        if contains(.maskShift) { result.append("shift") }
        if contains(.maskCommand) { result.append("cmd") }
        return result.joined(separator: "-")
    }
}

private let modifiersMap: [String: CGEventFlags] = [
    "shift": .maskShift,
    "alt": .maskAlternate,
    "ctrl": .maskControl,
    "cmd": .maskCommand,
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

struct Hotkey: Hashable, Sendable {
    let modifiers: CGEventFlags
    let key: String
    let description: String

    init(modifiers: CGEventFlags, key: String) {
        self.modifiers = modifiers
        self.key = key
        self.description = modifiers.isEmpty
            ? key
            : modifiers.toString() + "-" + key
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.modifiers == rhs.modifiers && lhs.key == rhs.key
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

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [Hotkey: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [Hotkey: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace)
            .flatMap { hotkey -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
                    HotkeyBinding(hotkey: hotkey, commands: $0)
                }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.hotkey) {
                errors.append(.semantic(backtrace, "'\(binding.hotkey.description)' Binding redeclaration"))
            }
            result[binding.hotkey] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace) -> ParsedToml<Hotkey> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<CGEventFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { CGEventFlags($0) }
    let key: ParsedToml<String> = rawKeys.last
        .flatMap { key in
            let key = String(key)
            if baseKeyCodeMap.values.contains(key) {
                return key
            }
            if let key = keyNames[key] {
                return key
            }
            if key.count == 1 {
                return key
            }

            return nil
        }
        .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedToml<Hotkey> in
        key.flatMap { key -> ParsedToml<Hotkey> in
            .success(Hotkey(modifiers: modifiers, key: key))
        }
    }
}
