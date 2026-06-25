import Common
import HotKey

struct Mode: ConvenienceMutable, Equatable, Sendable {
    var bindings: [String: HotkeyBinding]

    static let zero = Mode(bindings: [:])
}

func parseModes(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext, _ mapping: [String: Key]) -> [String: Mode] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &c, mapping)
    }
    if !result.keys.contains(mainModeId) {
        c.errors += [.init(backtrace, "Please specify '\(mainModeId)' mode")]
    }
    return result
}

func parseMode(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext, _ mapping: [String: Key]) -> Mode {
    guard let rawTable: OrderedJson.JsonDict = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
            case "binding":
                result.bindings = parseBindings(value, backtrace, &c, mapping)
            default:
                c.errors += [unknownKeyDiagnostic(backtrace)]
        }
    }
    return result
}
