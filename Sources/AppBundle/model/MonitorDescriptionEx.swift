import Common

extension MonitorDescription {
    func resolveMonitor(sortedMonitors: [Monitor]) -> Monitor? {
        return switch self {
            case .sequenceNumber(let number): sortedMonitors.getOrNil(atIndex: number - 1)
            case .main: mainMonitor
            case .secondary:
                sortedMonitors.takeIf { $0.count == 2 }?
                    .first { $0.rect.topLeftCorner != mainMonitor.rect.topLeftCorner }
            case .uuid(let uuid): sortedMonitors.first { $0.uuid.map { $0.uuidString == uuid } ?? false }
            case .contextualId(let id): sortedMonitors.first { $0.contextualId == id }
            case .serial(let id): sortedMonitors.first { $0.serial.map { $0 == id } ?? false }
            case .pattern(_, let regex): sortedMonitors.first { monitor in monitor.name.contains(regex.val) }
        }
    }
}
