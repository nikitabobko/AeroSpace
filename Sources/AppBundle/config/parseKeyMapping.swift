import AppKit
import Common
import HotKey
import TOMLKit

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyCode, parseKeyNotationToKeyCode),
    "mod-notation-to-mod-flags": Parser(\.rawModNotationToModFlags, parseModNotationToModFlags),
]

struct KeyMapping: Copyable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    public init(
        preset: Preset = .qwerty,
        rawKeyNotationToKeyCode: [String: Key] = [:],
        rawModNotationToModFlags: [String: NSEvent.ModifierFlags] = [:]
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
        self.rawModNotationToModFlags = rawModNotationToModFlags
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToKeyCode: [String: Key] = [:]
    fileprivate var rawModNotationToModFlags: [String: NSEvent.ModifierFlags] = [:]

    func resolveKeys() -> [String: Key] {
        getKeysPreset(preset) + rawKeyNotationToKeyCode
    }

    func resolveMods() -> [String: NSEvent.ModifierFlags] {
        rawModNotationToModFlags
    }
}

func parseKeyMapping(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedToml(backtrace) }
}

private func parseModNotationToModFlags(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: NSEvent.ModifierFlags] {
    var result: [String: NSEvent.ModifierFlags] = [:]
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return result
    }
    for (key, value): (String, TOMLValueConvertible) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let value = parseString(value, backtrace).getOrNil(appendErrorTo: &errors) {
                let modStrings = value.split(separator: "-")
                result[key] = []
                for modString in modStrings {
                    if let mod = modifiersMap[String(modString)] {
                        result[key]?.update(with: mod)
                    } else {
                        errors.append(.semantic(backtrace, "'\(value)' is invalid mod flag"))
                    }
                }
            }
        } else {
            errors.append(.semantic(backtrace, "'\(key)' is invalid mod notation"))
        }
    }
    return result
}

private func parseKeyNotationToKeyCode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: Key] {
    var result: [String: Key] = [:]
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return result
    }
    for (key, value): (String, TOMLValueConvertible) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let value = parseString(value, backtrace).getOrNil(appendErrorTo: &errors) {
                if let value = keyNotationToKeyCode[value] {
                    result[key] = value
                } else {
                    errors.append(.semantic(backtrace, "'\(value)' is invalid key code"))
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
