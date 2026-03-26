import Common

func parseWorkspaceToMonitorAssignment(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [String: [MonitorDescription]] {
    guard let rawTable = raw.asDictOrNil else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: [MonitorDescription]] = [:]
    for (workspaceName, rawMonitorDescription) in rawTable {
        result[workspaceName] = parseMonitorDescriptions(rawMonitorDescription, backtrace + .key(workspaceName), &errors)
    }
    return result
}

func parseMonitorDescriptions(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [MonitorDescription] {
    if let array = raw.asArrayOrNil {
        return array.enumerated()
            .map { (index, rawDesc) in parseMonitorDescription(rawDesc, backtrace + .index(index)).getOrNil(appendErrorTo: &errors) }
            .filterNotNil()
    } else {
        return parseMonitorDescription(raw, backtrace).getOrNil(appendErrorTo: &errors).asList()
    }
}

func parseMonitorDescription(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<MonitorDescription> {
    let rawString: String
    if let string = raw.asStringOrNil {
        rawString = string
    } else if let int = raw.asIntOrNil {
        rawString = String(int)
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .int], actual: raw.tomlType, backtrace))
    }

    return parseMonitorDescription(rawString).toParsedConfig(backtrace)
}
