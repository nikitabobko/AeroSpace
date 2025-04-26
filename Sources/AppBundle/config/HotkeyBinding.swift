import AppKit
import Common
import Foundation
import HotKey
import TOMLKit

@MainActor private var hotkeys: [String: HotKey] = [:]

@MainActor func resetHotKeys() {
    // Explicitly unregister all hotkeys. We cannot always rely on destruction of the HotKey object to trigger
    // unregistration because we might be running inside a hotkey handler that is keeping its HotKey object alive.
    for (_, key) in hotkeys {
        key.isEnabled = false
    }
    hotkeys = [:]
}

extension HotKey {
    var isEnabled: Bool {
        get { !isPaused }
        set {
            if isEnabled != newValue {
                isPaused = !newValue
            }
        }
    }
}

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    for binding in targetBindings.values where !hotkeys.keys.contains(binding.descriptionWithKeyCode) {
        hotkeys[binding.descriptionWithKeyCode] = HotKey(key: binding.keyCode, modifiers: binding.modifiers, keyDownHandler: {
            Task {
                if let activeMode {
                    try await runSession(.hotkeyBinding, .checkServerIsEnabledOrDie) { () throws in
                        _ = try await config.modes[activeMode]?.bindings[binding.descriptionWithKeyCode]?.commands
                            .runCmdSeq(.defaultEnv, .emptyStdin)
                    }
                }
            }
        })
    }
    for (binding, key) in hotkeys {
        if targetBindings.keys.contains(binding) {
            key.isEnabled = true
        } else {
            key.isEnabled = false
        }
    }
    activeMode = targetMode
}

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: Key
    let commands: [any Command]
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ modifiers: NSEvent.ModifierFlags, _ keyCode: Key, _ commands: [any Command], descriptionWithKeyNotation: String) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyCode = modifiers.isEmpty
            ? keyCode.toString()
            : modifiers.toString() + "-" + keyCode.toString()
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .flatMap { modifiers, key -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
                    HotkeyBinding(modifiers, key, $0, descriptionWithKeyNotation: binding)
                }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                errors.append(.semantic(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: Key]) -> ParsedToml<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedToml<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}
