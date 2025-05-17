import AppKit
import Common

// import Foundation // Common already imports Foundation
// import HotKey // REMOVE: No longer using HotKey.Key or HotKey objects here
import TOMLKit

// TODO: Refactor hotkey management. This will be replaced by CGEventTap logic.
// @MainActor private var hotkeys: [String: HotKey] = [:]

@MainActor func resetHotKeys() {
    // TODO: Refactor hotkey management.
    print("TODO: resetHotKeys needs to be refactored for CGEventTap")
}

// TODO: Refactor: HotKey extension will likely be removed.

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) {
    // TODO: Refactor hotkey management. This function will change significantly.
    print("TODO: activateMode needs to be refactored for CGEventTap. Current mode: \(targetMode ?? "none")")
    activeMode = targetMode
}

struct HotkeyBinding: Equatable, Sendable {
    let specificModifiers: Set<PhysicalModifierKey>
    let keyCode: UInt16 // NEW: Using virtual key code directly
    let commands: [any Command]
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ specificModifiers: Set<PhysicalModifierKey>, _ keyCode: UInt16, _ commands: [any Command], descriptionWithKeyNotation: String) {
        self.specificModifiers = specificModifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyCode = specificModifiers.isEmpty
            ? virtualKeyCodeToString(keyCode) // NEW: Use our helper from keysMap.swift
            : specificModifiers.toString() + "-" + virtualKeyCodeToString(keyCode) // NEW
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.specificModifiers == rhs.specificModifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: UInt16]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (bindingKeyString, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let itemBacktrace = backtrace + .key(bindingKeyString)
        let parsedBindingParts = parseBinding(bindingKeyString, itemBacktrace, mapping)

        let binding = parsedBindingParts.flatMap { specificModifiers, keyCode -> ParsedToml<HotkeyBinding> in
            parseCommandOrCommands(rawCommand).toParsedToml(itemBacktrace).map { commands -> HotkeyBinding in
                HotkeyBinding(specificModifiers, keyCode, commands, descriptionWithKeyNotation: bindingKeyString)
            }
        }
        .getOrNil(appendErrorTo: &errors)

        if let binding {
            // Using descriptionWithKeyNotation for uniqueness check as it's the raw string from config.
            // descriptionWithKeyCode might have collisions if virtualKeyCodeToString is not perfectly unique or canonical for all keys.
            if result.values.contains(where: { $0.descriptionWithKeyNotation == binding.descriptionWithKeyNotation && $0.descriptionWithKeyCode != binding.descriptionWithKeyCode }) {
                // This case is tricky, means same notation maps to different key codes due to presets etc.
                // However, descriptionWithKeyCode should be the canonical representation based on resolved key codes.
            }
            if result.keys.contains(binding.descriptionWithKeyCode) { // Check canonical form
                errors.append(.semantic(itemBacktrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration. Original binding notation was '\(binding.descriptionWithKeyNotation)'."))
            }
            result[binding.descriptionWithKeyCode] = binding // Store by canonical key code description
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: UInt16]) -> ParsedToml<(Set<PhysicalModifierKey>, UInt16)> {
    let rawKeys = raw.lowercased().split(separator: "-")
    let specificModifiersResult: ParsedToml<Set<PhysicalModifierKey>> = rawKeys.dropLast()
        .mapAllOrFailure { token -> ParsedToml<PhysicalModifierKey> in
            specificModifiersMap[String(token)].orFailure(.semantic(backtrace, "Can't parse modifier token '\(token)' in '\(raw)'. Available: \(specificModifiersMap.keys.joined(separator: ", "))"))
        }
        .map { Set($0) }

    let keyString = String(rawKeys.last ?? "")
    let key: ParsedToml<UInt16> = mapping[keyString]
        .orFailure(.semantic(backtrace, "Can't parse the key '\(keyString)' in '\(raw)' binding. Available keys: \(mapping.keys.sorted().joined(separator: ", "))"))

    return specificModifiersResult.flatMap { smods -> ParsedToml<(Set<PhysicalModifierKey>, UInt16)> in
        key.flatMap { k -> ParsedToml<(Set<PhysicalModifierKey>, UInt16)> in
            .success((smods, k))
        }
    }
}
