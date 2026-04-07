import Common

extension MonitorDescription {
    @MainActor func resolveMonitor(sortedMonitors: [Monitor]) -> Monitor? {
        switch self {
            case .sequenceNumber(let number): sortedMonitors.getOrNil(atIndex: number - 1)
            case .main: mainMonitor
            case .pattern(let regex): sortedMonitors.first { $0.name.contains(caseInsensitiveRegex: regex) }
            case .secondary:
                sortedMonitors.takeIf { $0.count == 2 }?
                    .first { $0.rect.topLeftCorner != mainMonitor.rect.topLeftCorner }
        }
    }
}
