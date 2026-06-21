import AppKit
import Common
import Foundation
import HotKey

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
@MainActor func activateMode(_ targetMode: String?) async throws {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    for binding in targetBindings.values where !hotkeys.keys.contains(binding.descriptionWithKeyCode) {
        hotkeys[binding.descriptionWithKeyCode] = HotKey(key: binding.keyCode, modifiers: binding.modifiers, keyDownHandler: {
            Task.startUnstructured {
                if let activeMode {
                    broadcastEvent(.bindingTriggered(
                        mode: activeMode,
                        binding: binding.descriptionWithKeyNotation,
                    ))
                    try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
                        _ = try await config.modes[activeMode]?.bindings[binding.descriptionWithKeyCode]?.commands
                            .run(.defaultEnv, .emptyStdin)
                    }
                }
            }
        })
    }
    for (binding, key) in hotkeys {
        key.isEnabled = targetBindings.keys.contains(binding)
    }
    let oldMode = activeMode
    activeMode = targetMode
    if oldMode != targetMode {
        broadcastEvent(.modeChanged(mode: targetMode))
        if !config.onModeChanged.isEmpty {
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.onModeChanged, token) {
                _ = try await config.onModeChanged.run(.defaultEnv, .emptyStdin)
            }
        }
    }
}

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: Key
    let commands: Shell<any Command>
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ modifiers: NSEvent.ModifierFlags, _ keyCode: Key, _ commands: Shell<any Command>, descriptionWithKeyNotation: String) {
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
            lhs.commands.equals(rhs.commands)
    }
}

func parseBindings(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext, _ mapping: [String: Key]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, OrderedJson) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .map { modifiers, key -> HotkeyBinding in
                let commands = parseShellOfCommandsForConfig(rawCommand, backtrace, &c)
                return HotkeyBinding(modifiers, key, commands, descriptionWithKeyNotation: binding)
            }
            .getOrNil(appendErrorTo: &c.errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                c.errors.append(.init(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: ConfigBacktrace, _ mapping: [String: Key]) -> ParsedConfig<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedConfig<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].toResult(.init(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedConfig<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .toResult(.init(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedConfig<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedConfig<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}
