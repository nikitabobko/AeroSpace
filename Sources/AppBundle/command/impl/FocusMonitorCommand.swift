import AppKit
import Common

struct FocusMonitorCommand: Command {
    let args: FocusMonitorCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        return switch args.target.val.resolve(target.workspace.workspaceMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor): targetMonitor.activeWorkspace.focusWorkspace()
            case .failure(let msg): io.err(msg)
        }
    }
}

extension MonitorTarget {
    func resolve(_ currentMonitor: Monitor, wrapAround: Bool) -> Result<Monitor, String> {
        switch self {
            case .direction(let direction):
                guard let (monitorsInDirection, index) = currentMonitor.findRelativeMonitor(inDirection: direction) else {
                    return .failure("Should never happen. Can't find the current monitor")
                }
                let targetMonitor = wrapAround ? monitorsInDirection.get(wrappingIndex: index) : monitorsInDirection.getOrNil(atIndex: index)
                guard let targetMonitor else {
                    return .failure("No monitors in direction \(direction)")
                }
                return .success(targetMonitor)
            case .relative(let nextPrev):
                let monitors = sortedMonitors
                guard let curIndex = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else {
                    return .failure("Can't find current monitor")
                }
                let targetIndex = nextPrev == .next ? curIndex + 1 : curIndex - 1
                let targetMonitor = wrapAround ? monitors.get(wrappingIndex: targetIndex) : monitors.getOrNil(atIndex: targetIndex)
                guard let targetMonitor else {
                    return .failure("Can't find target monitor")
                }
                return .success(targetMonitor)
            case .patterns(let patterns):
                let monitors = sortedMonitors
                guard let targetMonitor = patterns.lazy.compactMap({ $0.resolveMonitor(sortedMonitors: monitors) }).first else {
                    return .failure("None of the monitors match the pattern(s)")
                }
                return .success(targetMonitor)
        }
    }
}

extension Monitor {
    func relation(to monitor: Monitor) -> Orientation {
        guard let otherYRange = monitor.rect.minY.until(excl: monitor.rect.maxY) else { return .h }
        guard let myYRange = rect.minY.until(excl: rect.maxY) else { return .h }
        return myYRange.overlaps(otherYRange) ? .h : .v
    }

    func findRelativeMonitor(inDirection direction: CardinalDirection) -> (monitorsInDirection: [Monitor], index: Int)? {
        let currentMonitor = self
        let monitors = sortedMonitors.filter {
            currentMonitor.rect.topLeftCorner == $0.rect.topLeftCorner ||
                $0.relation(to: currentMonitor) == direction.orientation
        }
        guard let index = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else { return nil }
        return (monitors, index + direction.focusOffset)
    }
}
