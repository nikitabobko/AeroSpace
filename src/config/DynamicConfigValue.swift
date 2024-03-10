import Common

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
