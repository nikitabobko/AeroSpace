import Common
import TOMLKit

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(\.rawKeyNotationToKeyCode, parseKeyNotationToKeyCode),
    "match-key-event-by": Parser(\.matchKeyEventBy, parseMatchKeyEventBy),
]

struct KeyMapping: ConvenienceCopyable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    enum MatchKeyEventBy: String, CaseIterable, Sendable {
        case keyCode = "key-code"
        case keySymbol = "key-symbol"
    }

    init(
        preset: Preset = .qwerty,
        rawKeyNotationToKeyCode: [String: UInt32] = [:],
        matchKeyEventBy: MatchKeyEventBy = .keyCode,
    ) {
        self.preset = preset
        self.rawKeyNotationToKeyCode = rawKeyNotationToKeyCode
        self.matchKeyEventBy = matchKeyEventBy
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToKeyCode: [String: UInt32] = [:]
    fileprivate(set) var matchKeyEventBy: MatchKeyEventBy = .keyCode

    func resolve(_ symbol: String) -> UInt32? {
        if let keyCode = rawKeyNotationToKeyCode[symbol] {
            return keyCode
        }
        return getKeyMapPreset(preset)[symbol]
    }
}

func parseKeyMapping(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<KeyMapping.Preset> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.Preset.self).toParsedToml(backtrace) }
}

private func parseKeyNotationToKeyCode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: UInt32] {
    var result: [String: UInt32] = [:]
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

private func parseMatchKeyEventBy(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<KeyMapping.MatchKeyEventBy> {
    parseString(raw, backtrace).flatMap { parseEnum($0, KeyMapping.MatchKeyEventBy.self).toParsedToml(backtrace) }
}
