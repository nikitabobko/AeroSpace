import Common
import HotKey

struct Mode: ConvenienceCopyable, Equatable, Sendable {
    var bindings: [String: HotkeyBinding]

    static let zero = Mode(bindings: [:])
}

func parseModes(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError], _ mapping: [String: Key]) -> [String: Mode] {
    guard let rawTable = raw.asDictOrNil else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors, mapping)
    }
    if !result.keys.contains(mainModeId) {
        errors += [.semantic(backtrace, "Please specify '\(mainModeId)' mode")]
    }
    return result
}

func parseMode(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError], _ mapping: [String: Key]) -> Mode {
    guard let rawTable: Json.JsonDict = raw.asDictOrNil else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
            case "binding":
                result.bindings = parseBindings(value, backtrace, &errors, mapping)
            default:
                errors += [unknownKeyError(backtrace)]
        }
    }
    return result
}
