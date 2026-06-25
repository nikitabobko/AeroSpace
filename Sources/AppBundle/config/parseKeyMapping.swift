import Common
import HotKey

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyCode, parseKeyNotationToKeyCode),
]

struct KeyMapping: ConvenienceMutable, Equatable, Sendable {
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

func parseKeyMapping(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &c)
}

private func parsePreset(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedConfig(backtrace) }
}

private func parseKeyNotationToKeyCode(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: Key] {
    var result: [String: Key] = [:]
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
        return result
    }
    for (key, value): (String, OrderedJson) in table {
        if isValidKeyNotation(key) {
            let backtrace = backtrace + .key(key)
            if let value = parseString(value, backtrace).getOrNil(appendErrorTo: &c.errors) {
                switch keyNotationToKeyCode[value] {
                    case let value?: result[key] = value
                    case nil: c.errors.append(.init(backtrace, "\(value.singleQuoted) is invalid key code"))
                }
            }
        } else {
            c.errors.append(.init(backtrace, "\(key.singleQuoted) is invalid key notation"))
        }
    }
    return result
}

private func isValidKeyNotation(_ str: String) -> Bool {
    str.rangeOfCharacter(from: .whitespacesAndNewlines) == nil && !str.contains("-")
}
