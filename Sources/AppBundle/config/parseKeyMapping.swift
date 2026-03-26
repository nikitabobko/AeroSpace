import Common
import HotKey

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyCode, parseKeyNotationToKeyCode),
]

struct KeyMapping: ConvenienceCopyable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    init(
        preset: Preset = .qwerty,
        rawKeyNotationToKeyCode: [String: Key] = [:],
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToKeyCode: [String: Key] = [:]

    func resolve() -> [String: Key] {
        getKeysPreset(preset) + rawKeyNotationToKeyCode
    }
}

func parseKeyMapping(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedConfig(backtrace) }
}

private func parseKeyNotationToKeyCode(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [String: Key] {
    var result: [String: Key] = [:]
    guard let table = raw.asDictOrNil else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace))
        return result
    }
    for (key, value): (String, Json) in table {
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
