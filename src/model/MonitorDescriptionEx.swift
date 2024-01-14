extension MonitorDescription {
    func monitor(sortedMonitors: [Monitor]) -> Monitor? {
        switch self {
        case .sequenceNumber(let number):
            return sortedMonitors.getOrNil(atIndex: number - 1)
        case .main:
            return mainMonitor
        case .secondary:
            return sortedMonitors.takeIf { $0.count == 2 }?
                .first { $0.rect.topLeftCorner != mainMonitor.rect.topLeftCorner }
        case .pattern(let regex):
            return sortedMonitors.first { monitor in monitor.name.contains(regex) }
        }
    }
}

extension MonitorDescription: Equatable {
    public static func ==(lhs: MonitorDescription, rhs: MonitorDescription) -> Bool {
        switch (lhs, rhs) {
        case (.sequenceNumber(let a), .sequenceNumber(let b)):
            return a == b
        case (.main, .main):
            return true
        case (.secondary, .secondary):
            return true
        case (.pattern, .pattern):
            return true
        default:
            return false
        }
    }
}
