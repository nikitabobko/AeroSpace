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
    setEventTapBindings([])
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
@MainActor func activateMode_nonCancellable(_ targetMode: String?) async {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    // Bindings that name a side ('left-alt-h') can't be expressed as a Carbon hot key, so they
    // are handled by the event tap instead. See eventTapHotkeys.swift.
    for binding in targetBindings.values
        where binding.sidedModifiers.isEmpty && !hotkeys.keys.contains(binding.descriptionWithKeyCode)
    {
        hotkeys[binding.descriptionWithKeyCode] = HotKey(key: binding.keyCode, modifiers: binding.modifiers, keyDownHandler: {
            Task.startUnstructured { try await runHotkeyBinding(binding) }
        })
    }
    for (binding, key) in hotkeys {
        key.isEnabled = targetBindings.keys.contains(binding)
    }
    setEventTapBindings(Array(targetBindings.values))
    let oldMode = activeMode
    activeMode = targetMode
    if oldMode != targetMode {
        broadcastEvent(.modeChanged(mode: targetMode))
        _ = await config.onModeChanged.run(.defaultEnv, .emptyStdin)
    }
}

/// Shared by both delivery mechanisms: Carbon hot keys (HotKey) and the event tap.
@MainActor func runHotkeyBinding(_ binding: HotkeyBinding) async throws {
    if let activeMode {
        broadcastEvent(.bindingTriggered(
            mode: activeMode,
            binding: binding.descriptionWithKeyNotation,
        ))
        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
            _ = await config.modes[activeMode]?.bindings[binding.descriptionWithKeyCode]?.commands
                .run(.defaultEnv, .emptyStdin)
        }
    }
}

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: NSEvent.ModifierFlags
    /// Modifiers pinned to one physical side of the keyboard. Empty for ordinary bindings.
    /// The side independent flag of each one is also present in `modifiers`.
    let sidedModifiers: Set<SidedModifier>
    let keyCode: Key
    let commands: Shell<any Command>
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(
        _ modifiers: NSEvent.ModifierFlags,
        _ keyCode: Key,
        _ commands: Shell<any Command>,
        sidedModifiers: Set<SidedModifier> = [],
        descriptionWithKeyNotation: String,
    ) {
        self.modifiers = modifiers
        self.sidedModifiers = sidedModifiers
        self.keyCode = keyCode
        self.commands = commands
        // The side must be part of the identity, otherwise 'alt-h' and 'left-alt-h' would
        // collide in the bindings dictionary and be reported as a redeclaration.
        // Each sided modifier also contributes its side independent flag to `modifiers`, so drop
        // those here -- otherwise 'left-alt-2' would render as 'left-alt-alt-2'.
        let unsidedFlags = sidedModifiers.reduce(modifiers) { $0.subtracting($1.genericFlag) }
        let modifiersDescription = [sidedModifiers.toString(), unsidedFlags.toString()]
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        self.descriptionWithKeyCode = modifiersDescription.isEmpty
            ? keyCode.toString()
            : modifiersDescription + "-" + keyCode.toString()
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.sidedModifiers == rhs.sidedModifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            lhs.commands.strictEquals(rhs.commands)
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
            .map { parsed -> HotkeyBinding in
                let (modifiers, sidedModifiers, key) = parsed
                let commands = parseShellOfCommandsForConfig(rawCommand, backtrace, &c)
                return HotkeyBinding(modifiers, key, commands, sidedModifiers: sidedModifiers, descriptionWithKeyNotation: binding)
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

func parseBinding(
    _ raw: String,
    _ backtrace: ConfigBacktrace,
    _ mapping: [String: Key],
) -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Set<SidedModifier>, Key)> {
    let rawKeys = raw.split(separator: "-")
    let key: ResOrConfigParseDiagnostic<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .toResult(.init(backtrace, "Can't parse the key in '\(raw)' binding"))

    let modifiers = parseModifiers(rawKeys.dropLast().map(String.init), raw, backtrace)
    return modifiers.flatMap { modifiers -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Set<SidedModifier>, Key)> in
        key.flatMap { key -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Set<SidedModifier>, Key)> in
            .success((modifiers.0, modifiers.1, key))
        }
    }
}

private func parseModifiers(
    _ rawModifiers: [String],
    _ raw: String,
    _ backtrace: ConfigBacktrace,
) -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Set<SidedModifier>)> {
    // 'left'/'right' belongs to the modifier that follows it: 'left-alt-h' is (left alt) + h.
    // Only modifier positions are merged, so the 'left'/'right' arrow keys still parse as keys.
    var tokens: [String] = []
    var i = 0
    while i < rawModifiers.count {
        if (rawModifiers[i] == "left" || rawModifiers[i] == "right") && i + 1 < rawModifiers.count {
            tokens.append(rawModifiers[i] + "-" + rawModifiers[i + 1])
            i += 2
        } else {
            tokens.append(rawModifiers[i])
            i += 1
        }
    }

    var flags: NSEvent.ModifierFlags = []
    var sided: Set<SidedModifier> = []
    for token in tokens {
        if let sidedModifier = sidedModifiersMap[token] {
            sided.insert(sidedModifier)
            flags.insert(sidedModifier.genericFlag)
        } else if let flag = modifiersMap[token] {
            flags.insert(flag)
        } else {
            return .failure(.init(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
    }
    // 'left-alt-right-alt-h' can never fire: both alt keys would have to be the only alt down.
    if let conflict = sided.first(where: { sided.contains($0.otherSide) }) {
        return .failure(.init(
            backtrace,
            "'\(raw)' binding requires both '\(conflict.notation)' and '\(conflict.otherSide.notation)', which can never match",
        ))
    }
    return .success((flags, sided))
}
