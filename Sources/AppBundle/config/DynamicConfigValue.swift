import Common

struct PerMonitorValue<Value: Equatable>: Equatable {
    let description: MonitorDescription
    let value: Value
}
extension PerMonitorValue: Sendable where Value: Sendable {}

struct PerWorkspaceValue<Value: Equatable>: Equatable {
    let workspaceName: String
    let value: Value
}
extension PerWorkspaceValue: Sendable where Value: Sendable {}

enum DynamicConfigValue<Value: Equatable>: Equatable {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value)
    case perWorkspace([PerWorkspaceValue<Value>], default: Value)
}
extension DynamicConfigValue: Sendable where Value: Sendable {}

extension DynamicConfigValue {
    @MainActor func getValue(for monitor: any Monitor, workspace: String? = nil) -> Value {
        switch self {
            case .constant(let value): return value
            case .perMonitor(let array, let defaultValue):
                let sortedMonitors = sortedMonitors
                return array
                    .lazy
                    .compactMap {
                        $0.description.resolveMonitor(sortedMonitors: sortedMonitors)?.rect.topLeftCorner == monitor.rect.topLeftCorner
                            ? $0.value
                            : nil
                    }
                    .first ?? defaultValue
            case .perWorkspace(let array, let defaultValue):
                guard let workspace else { return defaultValue }
                return array.first { $0.workspaceName == workspace }?.value ?? defaultValue
        }
    }
}

func parseDynamicValue<T>(
    _ raw: Json,
    ofType valueType: T.Type,
    _ fallback: T,
    _ backtrace: ConfigBacktrace,
    _ errors: inout [ConfigParseError],
) -> DynamicConfigValue<T> {
    if let simpleValue = parseSimpleType(raw, ofType: T.self) {
        return .constant(simpleValue)
    } else if let array = raw.asArrayOrNil {
        if array.isEmpty {
            errors.append(.semantic(backtrace, "The array must not be empty"))
            return .constant(fallback)
        }

        guard let defaultValue = array.last.flatMap({ parseSimpleType($0, ofType: T.self) }) else {
            errors.append(.semantic(backtrace, "The last item in the array must be of type \(T.self)"))
            return .constant(fallback)
        }

        if array.dropLast().isEmpty {
            errors.append(.semantic(backtrace, "The array must contain at least one monitor or workspace pattern"))
            return .constant(fallback)
        }

        let rules = Array(array.dropLast())
        if let first = rules.first, first.asDictOrNil?.keys.contains("workspace") == true {
            let workspaceRules: [PerWorkspaceValue<T>] = parsePerWorkspaceValues(rules, backtrace, &errors)
            return .perWorkspace(workspaceRules, default: defaultValue)
        } else {
            let monitorRules: [PerMonitorValue<T>] = parsePerMonitorValues(rules, backtrace, &errors)
            return .perMonitor(monitorRules, default: defaultValue)
        }
    } else {
        errors.append(.semantic(backtrace, "Unsupported type: \(raw.tomlType), expected: \(valueType) or array"))
        return .constant(fallback)
    }
}

func parsePerWorkspaceValues<T>(_ array: Json.JsonArray, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [PerWorkspaceValue<T>] {
    array.enumerated().compactMap { (index: Int, raw: Json) -> PerWorkspaceValue<T>? in
        var backtrace = backtrace + .index(index)

        guard let (workspaceName, value) = raw.unwrapTableWithSingleKey(expectedKey: "workspace", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors)
        else {
            return nil
        }

        switch WorkspaceName.parse(workspaceName) {
            case .failure(let err):
                errors.append(.semantic(backtrace, err))
                return nil
            case .success: break
        }

        guard let value = parseSimpleType(value, ofType: T.self) else {
            errors.append(.semantic(backtrace, "Expected type is '\(T.self)'. But actual type is '\(value.tomlType)'"))
            return nil
        }

        return PerWorkspaceValue(workspaceName: workspaceName, value: value)
    }
}

func parsePerMonitorValues<T>(_ array: Json.JsonArray, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [PerMonitorValue<T>] {
    array.enumerated().compactMap { (index: Int, raw: Json) -> PerMonitorValue<T>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors)
        else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(.string(key), backtrace)

        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        guard let value = parseSimpleType(value, ofType: T.self) else {
            errors.append(.semantic(backtrace, "Expected type is '\(T.self)'. But actual type is '\(value.tomlType)'"))
            return nil
        }

        return PerMonitorValue(description: monitorDescription, value: value)
    }
}
