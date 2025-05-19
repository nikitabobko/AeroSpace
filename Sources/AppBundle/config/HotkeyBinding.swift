import AppKit
import Common

// import Foundation // Common already imports Foundation
// REMOVED: import HotKey // REMOVE: No longer using HotKey.Key or HotKey objects here
import TOMLKit

// Block of TODOs and old comments removed.

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) {
    activeMode = targetMode
    GlobalHotkeyMonitor.shared.updateBindingsCache()
}

// Define GenericModifierType here if not accessible from keysMap.swift or for clarity
// For now, assuming it's available from keysMap.swift via `import Common` or similar in consuming files
// If not, it should be defined here or in a shared Common place.

struct HotkeyBinding: Equatable, Sendable {
    let exactModifiers: Set<PhysicalModifierKey>
    let genericModifiers: Set<GenericModifierType>  // Assumes GenericModifierType is defined (e.g., in keysMap.swift)
    let keyCode: UInt16
    let commands: [any Command]
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(
        exactModifiers: Set<PhysicalModifierKey> = [],  // Default to empty set
        genericModifiers: Set<GenericModifierType> = [],  // Default to empty set
        keyCode: UInt16,
        commands: [any Command],
        descriptionWithKeyNotation: String
    ) {
        self.exactModifiers = exactModifiers
        self.genericModifiers = genericModifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyNotation = descriptionWithKeyNotation

        // Construct descriptionWithKeyCode carefully based on exact and generic modifiers
        var modifierParts: [String] = []  // Ensure GenericModifierType is accessible here
        modifierParts += self.exactModifiers.sorted(by: { $0.rawValue < $1.rawValue }).map {
            $0.configKey
        }
        modifierParts += self.genericModifiers.sorted(by: { $0.rawValue < $1.rawValue }).map {
            $0.rawValue
        }

        // Critical: Ensure canonical representation by sorting and removing duplicates if any were allowed by parsing (parser should prevent this)
        let sortedModifierString = modifierParts.sorted().joined(separator: "-")

        self.descriptionWithKeyCode =
            sortedModifierString.isEmpty
                ? virtualKeyCodeToString(keyCode)
                : sortedModifierString + "-" + virtualKeyCodeToString(keyCode)
    }

    // REMOVED commented-out convenience init

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        // Equality should primarily depend on the effective modifiers, keycode, and commands.
        // descriptionWithKeyCode should be canonical if parsing is correct.
        lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode  // This relies on canonical description
            && lhs.keyCode == rhs.keyCode  // keyCode is part of descriptionWithKeyCode, but good to be explicit
            && lhs.exactModifiers == rhs.exactModifiers  // Explicit check
            && lhs.genericModifiers == rhs.genericModifiers  // Explicit check
            && lhs.commands.count == rhs.commands.count  // Add count check
            && zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }  // Command equality
    }
}

func parseBindings(
    _ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError],
    _ mapping: [String: UInt16]
) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (bindingKeyString, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let itemBacktrace = backtrace + .key(bindingKeyString)

        let binding = parseBinding(bindingKeyString, itemBacktrace, mapping).flatMap {
            components -> ParsedToml<HotkeyBinding> in
            parseCommandOrCommands(rawCommand).toParsedToml(itemBacktrace).map {
                commands -> HotkeyBinding in
                HotkeyBinding(
                    exactModifiers: components.exact,
                    genericModifiers: components.generic,
                    keyCode: components.keyCode,
                    commands: commands,
                    descriptionWithKeyNotation: bindingKeyString
                )
            }
        }
        .getOrNil(appendErrorTo: &errors)

        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                errors.append(
                    .semantic(
                        itemBacktrace,
                        "'\(binding.descriptionWithKeyCode)' Binding redeclaration. Original binding notation was '\(binding.descriptionWithKeyNotation)'."
                    )
                )
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: UInt16])
    -> ParsedToml<
        (exact: Set<PhysicalModifierKey>, generic: Set<GenericModifierType>, keyCode: UInt16)
    >
{
    let rawKeys = raw.lowercased().split(separator: "-")
    guard !rawKeys.isEmpty else {
        return .failure(.semantic(backtrace, "Binding string cannot be empty."))
    }

    var exactModifiers = Set<PhysicalModifierKey>()
    var genericModifiers = Set<GenericModifierType>()

    for token in rawKeys.dropLast() {
        let tokenString = String(token)
        if let physicalMod = specificModifiersMap[tokenString] {
            guard !exactModifiers.contains(physicalMod) else {
                return .failure(
                    .semantic(
                        backtrace, "Duplicate specific modifier '\(tokenString)' in '\(raw)'."))
            }
            exactModifiers.insert(physicalMod)
        } else if let genericMod = genericModifiersMap[tokenString] {
            guard !genericModifiers.contains(genericMod) else {
                return .failure(
                    .semantic(backtrace, "Duplicate generic modifier '\(tokenString)' in '\(raw)'.")
                )
            }
            genericModifiers.insert(genericMod)
        } else {
            let availableSpecific = specificModifiersMap.keys.sorted().joined(separator: ", ")
            let availableGeneric = genericModifiersMap.keys.sorted().joined(separator: ", ")
            return .failure(
                .semantic(
                    backtrace,
                    "Can't parse modifier token '\(tokenString)' in '\(raw)'. Available specific: [\(availableSpecific)]. Available generic: [\(availableGeneric)]."
                )
            )
        }
    }

    // Validation: Generic vs Specific conflicts
    for genModType in genericModifiers {
        let specificCounterparts: Set<PhysicalModifierKey> =
            switch genModType {
                case .option: [.leftOption, .rightOption]
                case .command: [.leftCommand, .rightCommand]
                case .control: [.leftControl, .rightControl]
                case .shift: [.leftShift, .rightShift]
            }
        if !exactModifiers.isDisjoint(with: specificCounterparts) {
            return .failure(
                .semantic(
                    backtrace,
                    "Binding '\(raw)' cannot specify both a generic modifier for '\(genModType.rawValue)' (e.g., '\(exampleGenericToken(for: genModType))') and a specific one (e.g., 'lalt', 'ralt') for the same type."
                )
            )
        }
    }

    // Validation: lctrl and rctrl for example implies ctrl. User can't specify lctrl and ctrl for example.
    // This is implicitly handled by the previous check: if `genericModifiers` contains `.control`
    // and `exactModifiers` contains `.leftControl`, it's an error.

    let keyString = String(rawKeys.last!)
    let keyBinding: ParsedToml<UInt16> = mapping[keyString]
        .orFailure(
            .semantic(
                backtrace,
                "Can't parse the key '\(keyString)' in '\(raw)' binding. Available keys: \(mapping.keys.sorted().joined(separator: ", "))"
            )
        )

    return keyBinding.map {
        keyCode -> (
            exact: Set<PhysicalModifierKey>, generic: Set<GenericModifierType>, keyCode: UInt16
        ) in
        return (exact: exactModifiers, generic: genericModifiers, keyCode: keyCode)
    }
}

private func exampleGenericToken(for type: GenericModifierType) -> String {
    // Return a common token for the generic type
    switch type {
        case .option: return "alt"
        case .command: return "cmd"
        case .control: return "ctrl"
        case .shift: return "shift"
    }
}
