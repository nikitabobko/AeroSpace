import AppKit
import Common
import HotKey
import TOMLKit

enum KeyOrModifier: Equatable, Sendable {
    case key(Key)
    case modifiers(NSEvent.ModifierFlags)
}

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyOrModifier, parseKeyNotationToKeyOrModifier),
]

struct KeyMapping: ConvenienceCopyable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    init(
        preset: Preset = .qwerty,
        rawKeyNotationToKeyOrModifier: [String: KeyOrModifier] = [:]
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyOrModifier = rawKeyNotationToKeyOrModifier
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToKeyOrModifier: [String: KeyOrModifier] = [:]

    func resolve() -> [String: KeyOrModifier] {
        let presetKeys = getKeysPreset(preset).mapValues { KeyOrModifier.key($0) }
        return presetKeys + rawKeyNotationToKeyOrModifier
    }
}

func parseKeyMapping(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedToml(backtrace) }
}

private func parseKeyNotationToKeyOrModifier(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: KeyOrModifier] {
    var result: [String: KeyOrModifier] = [:]
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return result
    }

    for (key, value): (String, TOMLValueConvertible) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let valueString = parseString(value, backtrace).getOrNil(appendErrorTo: &errors) {
                if let (modifiers, parsedKey) = parseValueComponents(valueString, backtrace, &errors) {
                    if !modifiers.isEmpty && parsedKey != nil {
                        errors.append(.semantic(backtrace, "'\(valueString)' contains both keys and modifiers, which is not supported. Use either a single key (e.g., 'a') or modifier combination (e.g., 'ctrl-alt-shift-cmd')"))
                        continue
                    }

                    if let parsedKey {
                        result[key] = .key(parsedKey)
                    } else if !modifiers.isEmpty {
                        result[key] = .modifiers(modifiers)
                    } else {
                        errors.append(.semantic(backtrace, "'\(valueString)' is not a valid key"))
                    }
                }
            }
        } else {
            errors.append(.semantic(backtrace, "'\(key)' is invalid key notation"))
        }
    }
    return result
}

private func isValidKeyNotation(_ str: String) -> Bool {
    str.rangeOfCharacter(from: .whitespacesAndNewlines) == nil && !str.contains("-")
}

private func parseValueComponents(_ valueString: String, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> (modifiers: NSEvent.ModifierFlags, key: Key?)? {
    let parts = valueString.split(separator: "-").map(String.init)
    var modifiers: NSEvent.ModifierFlags = []
    var key: Key? = nil

    for part in parts {
        if let modifier = modifiersMap[part] {
            modifiers.insert(modifier)
        } else if let parsedKey = keyNotationToKeyCode[part] {
            if key != nil {
                errors.append(.semantic(backtrace, "'\(valueString)' contains multiple keys, only one key is allowed"))
                return nil
            }
            key = parsedKey
        } else {
            errors.append(.semantic(backtrace, "'\(part)' is invalid key code"))
            return nil
        }
    }

    return (modifiers: modifiers, key: key)
}
