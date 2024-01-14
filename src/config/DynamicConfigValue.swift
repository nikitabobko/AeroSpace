typealias PerMonitorValue<Value: Equatable> = (description: MonitorDescription, value: Value)

enum DynamicConfigValue<Value: Equatable> {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value?)
}

extension DynamicConfigValue {
    func getValue(for monitor: (any Monitor)?, fallbackValue: Value) -> Value {
        switch self {
        case .constant(let value):
            return value
        case .perMonitor(let array, let defaultValue):
            if let monitor {
                let sortedMonitors = sortedMonitors
                return array
                    .lazy
                    .compactMap {
                        $0.description.monitor(sortedMonitors: sortedMonitors)?.name == monitor.name
                            ? $0.value
                            : nil
                    }
                    .first
                    ?? defaultValue
                    ?? fallbackValue
            } else {
                return defaultValue ?? fallbackValue
            }
        }
    }
}
