import Common
import Foundation
import TOMLKit

struct PerMonitorValue<Value: Equatable>: Equatable {
    let description: MonitorDescription
    let value: Value
    let windows: Int?
    let workspace: String?
}
extension PerMonitorValue: Sendable where Value: Sendable {}

enum DynamicConfigValue<Value: Equatable>: Equatable {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value)
}
extension DynamicConfigValue: Sendable where Value: Sendable {}

extension DynamicConfigValue {
    @MainActor
    func getValue(for monitor: any Monitor, windowCount: Int = 1) -> Value {
        let actualWindowCount = getActualWindowCount(monitor: monitor, windowCount: windowCount)

        switch self {
            case .constant(let value):
                return value
            case .perMonitor(let array, let defaultValue):
                return getPerMonitorValue(
                    array: array,
                    monitor: monitor,
                    windowCount: actualWindowCount,
                    defaultValue: defaultValue
                )
        }
    }

    @MainActor
    private func getActualWindowCount(monitor: any Monitor, windowCount: Int) -> Int {
        guard !isUnitTest else { return windowCount }

        return monitor.activeWorkspace.allLeafWindowsRecursive
            .filter { !$0.isFloating }
            .count
    }

    private func isMonitorMatching(_ description: MonitorDescription, _ monitor: any Monitor) -> Bool {
        switch description {
            case .main: return monitor.name == "main"
            case .secondary: return monitor.name == "secondary"
            case .pattern(_, let regex): return (try? regex.val.firstMatch(in: monitor.name)) != nil
            case .sequenceNumber(let num): return num == monitor.monitorAppKitNsScreenScreensId
        }
    }

    private func matchesWorkspace(_ pattern: String?, _ workspaceName: String) -> Bool {
        guard let pattern else { return true }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(workspaceName.startIndex..., in: workspaceName)
        return regex.firstMatch(in: workspaceName, range: range) != nil
    }

    @MainActor
    private func getPerMonitorValue(
        array: [PerMonitorValue<Value>],
        monitor: any Monitor,
        windowCount: Int,
        defaultValue: Value
    ) -> Value {
        let matchingValues = array.filter { isMonitorMatching($0.description, monitor) }
        let workspaceName = monitor.activeWorkspace.name

        if let value = matchingValues.first(where: {
            $0.windows == windowCount && matchesWorkspace($0.workspace, workspaceName)
        }) {
            return value.value
        }

        if let value = matchingValues.first(where: {
            $0.windows == nil && matchesWorkspace($0.workspace, workspaceName)
        }) {
            return value.value
        }

        return matchingValues.first(where: {
            $0.windows == nil && $0.workspace == nil
        })?.value ?? defaultValue
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
    }

    guard let array = raw.array, !array.isEmpty else {
        errors.append(.semantic(backtrace, "Expected non-empty array"))
        return .constant(fallback)
    }

    guard let defaultValue = array.last.flatMap({ parseSimpleType($0) as T? }) else {
        errors.append(.semantic(backtrace, "The last item in the array must be of type \(T.self)"))
        return .constant(fallback)
    }

    let rules = parsePerMonitorValues(TOMLArray(array.dropLast()), backtrace, &errors) as [PerMonitorValue<T>]
    return .perMonitor(rules, default: defaultValue)
}

func parsePerMonitorValues<T>(_ array: TOMLArray, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [PerMonitorValue<T>] {
    array.enumerated().compactMap { (index, raw) in
        var backtrace = backtrace + .index(index)

        guard let (key, configValue) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors),
            let monitorDescription = parseMonitorDescription(key, backtrace).getOrNil(appendErrorTo: &errors)
        else { return nil }

        if let simpleValue = parseSimpleType(configValue) as T? {
            return PerMonitorValue(description: monitorDescription, value: simpleValue, windows: nil, workspace: nil)
        }

        guard let table = configValue.table,
              let value = table["value"].flatMap({ parseSimpleType($0) as T? })
        else {
            errors.append(.semantic(backtrace, "Expected '\(T.self)' or table with 'value' field"))
            return nil
        }

        let windows = table["windows"].flatMap { parseSimpleType($0) as Int? }
        let workspace = table["workspace"].flatMap { parseSimpleType($0) as String? }

        if let workspace, (try? NSRegularExpression(pattern: workspace)) == nil {
            errors.append(.semantic(backtrace, "Invalid workspace pattern"))
            return nil
        }

        return PerMonitorValue(
            description: monitorDescription,
            value: value,
            windows: windows,
            workspace: workspace
        )
    }
}
