import Common

extension MonitorDescription {
    func resolveMonitor(sortedMonitors: [Monitor]) -> Monitor? {
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
