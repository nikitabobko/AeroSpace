import Common

func parseWorkspaceToMonitorAssignment(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: [MonitorDescription]] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: [MonitorDescription]] = [:]
    for (workspaceName, rawMonitorDescription) in rawTable {
        result[workspaceName] = parseMonitorDescriptions(rawMonitorDescription, backtrace + .key(workspaceName), &c)
    }
    return result
}

func parseMonitorDescriptions(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [MonitorDescription] {
    if let array = raw.asArrayOrNil {
        return array.enumerated()
            .map { (index, rawDesc) in parseMonitorDescription(rawDesc, backtrace + .index(index)).getOrNil(appendErrorTo: &c.errors) }
            .filterNotNil()
    } else {
        return parseMonitorDescription(raw, backtrace).getOrNil(appendErrorTo: &c.errors).asList()
    }
}

func parseMonitorDescription(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<MonitorDescription> {
    let rawString: String
    if let string = raw.asStringOrNil {
        rawString = string
    } else if let int = raw.asIntOrNil {
        rawString = String(int)
    } else {
        return .failure(expectedActualTypeDiagnostic(expected: [.string, .int], actual: raw.tomlType, backtrace))
    }

    return parseMonitorDescription(rawString).toParsedConfig(backtrace)
}

/// Only name patterns make sense here: sequence numbers, `main` and `secondary` are resolved against the monitors
/// that remain after the ignored ones are filtered out.
func parseIgnoredMonitors(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [CaseInsensitiveRegex] {
    guard let array = raw.asArrayOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .array, actual: raw.tomlType, backtrace)]
        return []
    }
    return array.enumerated()
        .map { (index, rawDesc) in
            let backtrace = backtrace + .index(index)
            return parseMonitorDescription(rawDesc, backtrace)
                .flatMap { description -> ResOrConfigParseDiagnostic<CaseInsensitiveRegex> in
                    switch description {
                        case .pattern(let regex): .success(regex)
                        case .main: .failure(notAPattern(backtrace, "main"))
                        case .secondary: .failure(notAPattern(backtrace, "secondary"))
                        case .sequenceNumber(let number): .failure(notAPattern(backtrace, String(number)))
                    }
                }
                .getOrNil(appendErrorTo: &c.errors)
        }
        .filterNotNil()
}

private func notAPattern(_ backtrace: ConfigBacktrace, _ raw: String) -> ConfigParseDiagnostic {
    ConfigParseDiagnostic(backtrace, "Only monitor name patterns can be ignored. \(raw.singleQuoted) is not a pattern")
}
