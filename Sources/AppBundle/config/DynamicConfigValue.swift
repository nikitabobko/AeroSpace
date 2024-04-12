import Common
import TOMLKit

typealias PerMonitorValue<Value: Equatable> = (description: MonitorDescription, value: Value)

enum DynamicConfigValue<Value: Equatable> {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value)
}

extension DynamicConfigValue {
    func getValue(for monitor: any Monitor) -> Value {
        switch self {
            case .constant(let value):
                return value
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
        }
    }
}

func parseDynamicValue<T>(
    _ raw: TOMLValueConvertible,
    _ valueType: T.Type,
    _ fallback: T,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> DynamicConfigValue<T> {
    if let simpleValue = parseSimpleType(raw) as T? {
        return .constant(simpleValue)
    } else if let array = raw.array {
        if array.isEmpty {
            errors.append(.semantic(backtrace, "The array must not be empty"))
            return .constant(fallback)
        }

        guard let defaultValue = array.last.flatMap({ parseSimpleType($0) as T? }) else {
            errors.append(.semantic(backtrace, "The last item in the array must be of type \(T.self)"))
            return .constant(fallback)
        }

        if array.dropLast().isEmpty {
            errors.append(.semantic(backtrace, "The array must contain at least one monitor pattern"))
            return .constant(fallback)
        }

        let rules: [PerMonitorValue<T>] = parsePerMonitorValues(TOMLArray(array.dropLast()), backtrace, &errors)

        return .perMonitor(rules, default: defaultValue)
    } else {
        errors.append(.semantic(backtrace, "Unsupported type: \(raw.type), expected: \(valueType) or array"))
        return .constant(fallback)
    }
}

func parsePerMonitorValues<T>(_ array: TOMLArray, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [PerMonitorValue<T>] {
    array.enumerated().compactMap { (index: Int, raw: TOMLValueConvertible) -> PerMonitorValue<T>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors) else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(key, backtrace)

        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        guard let value = parseSimpleType(value) as T? else {
            errors.append(.semantic(backtrace, "Expected type is '\(T.self)'. But actual type is '\(value.type)'"))
            return nil
        }

        return (description: monitorDescription, value: value) as PerMonitorValue<T>
    }
}
