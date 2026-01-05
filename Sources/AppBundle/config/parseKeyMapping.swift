import Common

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
        rawKeyNotationToKeyCode: [String: UInt32] = [:],
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToKeyCode: [String: UInt32] = [:]

    func resolve() -> [String: UInt32] {
        getKeysPreset(preset) + rawKeyNotationToKeyCode
    }
}

func parseKeyMapping(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedConfig(backtrace) }
}

private func parseKeyNotationToKeyCode(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [String: UInt32] {
    var result: [String: UInt32] = [:]
    guard let table = raw.asDictOrNil else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace))
        return result
    }
    for (key, value): (String, Json) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let value = parseString(value, backtrace).getOrNil(appendErrorTo: &errors) {
                switch keyNotationToKeyCode[value] {
                    case let value?: result[key] = value
                    case nil: errors.append(.semantic(backtrace, "\(value.singleQuoted) is invalid key code"))
                }
            }
        } else {
            errors.append(.semantic(backtrace, "\(key.singleQuoted) is invalid key notation"))
        }
    }
    return result
}

private func isValidKeyNotation(_ str: String) -> Bool {
    str.rangeOfCharacter(from: .whitespacesAndNewlines) == nil && !str.contains("-")
}
