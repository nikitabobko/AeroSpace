import Common

func parseWorkspaceLayout(
    _ raw: OrderedJson,
    _ backtrace: ConfigBacktrace,
    _ c: inout ConfigParserContext,
) -> [String: LayoutSkeleton] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: LayoutSkeleton] = [:]
    for (workspaceName, rawValue) in rawTable {
        let backtrace = backtrace + .key(workspaceName)
        guard let source = rawValue.asStringOrNil else {
            c.errors += [expectedActualTypeDiagnostic(expected: .string, actual: rawValue.tomlType, backtrace)]
            continue
        }
        switch LayoutSkeleton.parse(source) {
            case .success(let skeleton): result[workspaceName] = skeleton
            case .failure(let error): c.errors += [.init(backtrace, "Can't parse the layout: \(error.description)")]
        }
    }
    return result
}
