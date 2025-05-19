import Common
import TOMLKit

private let keyMappingParser: [String: any ParserProtocol<KeyMapping>] = [
    "preset": Parser(\.preset, parsePreset),
    "key-notation-to-key-code": Parser(
        \.rawKeyNotationToVirtualKeyCode, parseKeyNotationToVirtualKeyCode),
]

struct KeyMapping: ConvenienceCopyable, Equatable, Sendable {
    enum Preset: String, CaseIterable, Sendable {
        case qwerty, dvorak, colemak
    }

    init(
        preset: Preset = .qwerty,
        rawKeyNotationToVirtualKeyCode: [String: UInt16] = [:]
    ) {
        self.preset = preset
        self.rawKeyNotationToVirtualKeyCode = rawKeyNotationToVirtualKeyCode
    }

    fileprivate var preset: Preset = .qwerty
    fileprivate var rawKeyNotationToVirtualKeyCode: [String: UInt16] = [:]

    func resolve() -> [String: UInt16] {
        getKeysPreset(preset) + rawKeyNotationToVirtualKeyCode
    }
}

func parseKeyMapping(
    _ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]
) -> KeyMapping {
    parseTable(raw, KeyMapping(), keyMappingParser, backtrace, &errors)
}

private func parsePreset(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<
    KeyMapping.Preset
> {
    parseString(raw, backtrace).flatMap {
        parseEnum($0, KeyMapping.Preset.self).toParsedToml(backtrace)
    }
}

private func parseKeyNotationToVirtualKeyCode(
    _ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]
) -> [String: UInt16] {
    var result: [String: UInt16] = [:]
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return result
    }
    for (customKeyNotation, keyCodeStringValue): (String, TOMLValueConvertible) in table {
        let normalizedKey = customKeyNotation.lowercased()
        let itemBacktrace = backtrace + .key(customKeyNotation)

        if isValidKeyNotation(normalizedKey) {
            if let keyCodeString = parseString(keyCodeStringValue, itemBacktrace).getOrNil(
                appendErrorTo: &errors)
            {
                if let virtualKeyCode = keyNotationToVirtualKeyCode[keyCodeString.lowercased()] {
                    if result[normalizedKey] != nil {
                        errors.append(
                            .semantic(
                                itemBacktrace,
                                "Duplicate definition for custom key notation '\(customKeyNotation)' (normalizes to '\(normalizedKey)')"
                            ))
                    } else {
                        result[normalizedKey] = virtualKeyCode
                    }
                } else {
                    errors.append(
                        .semantic(
                            itemBacktrace,
                            "'\(keyCodeString)' is an invalid key string. It does not map to a known virtual key code. Check keysMap.swift for available keys."
                        ))
                }
            }
        } else {
            errors.append(
                .semantic(
                    itemBacktrace,
                    "'\(customKeyNotation)' is invalid as a custom key notation string. It must not be empty and must not contain spaces or '-'."
                ))
        }
    }
    return result
}

private func isValidKeyNotation(_ str: String) -> Bool {
    !str.isEmpty
        && str.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        && !str.contains("-")
}
