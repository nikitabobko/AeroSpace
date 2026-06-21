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
