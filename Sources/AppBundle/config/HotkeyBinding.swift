import AppKit
import Foundation
import HotKey
import TOMLKit

private var hotkeys: [String: HotKey] = [:]

func resetHotKeys() {
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

var activeMode: String? = mainModeId
func activateMode(_ targetMode: String?) {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    for binding in targetBindings.values where !hotkeys.keys.contains(binding.binding) {
        hotkeys[binding.binding] = HotKey(key: binding.key, modifiers: binding.modifiers, keyUpHandler: {
            if let activeMode {
                refreshSession(forceFocus: true) {
                    _ = config.modes[activeMode]?.bindings[binding.binding]?.commands.run(.focused)
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

struct HotkeyBinding {
    let modifiers: NSEvent.ModifierFlags
    let key: Key
    let commands: [any Command]
    let binding: String

    init(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ commands: [any Command]) {
        self.modifiers = modifiers
        self.key = key
        self.commands = commands
        self.binding = modifiers.isEmpty ? key.description : modifiers.toString() + "-\(key)"
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
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map { HotkeyBinding(modifiers, key, $0) }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.binding) {
                errors.append(.semantic(backtrace, "'\(binding.binding)' Binding redeclaration"))
            }
            result[binding.binding] = binding
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
