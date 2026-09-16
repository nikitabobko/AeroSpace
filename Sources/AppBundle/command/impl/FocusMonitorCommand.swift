import AppKit
import Common

struct FocusMonitorCommand: Command {
    let args: FocusMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        switch args.target.val.resolve(target.workspace.workspaceMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                let success = targetMonitor.activeWorkspace.focusWorkspace()
                // Re-assert macOS focus unconditionally.
                //
                // setFocus() returns early when the model already equals the
                // request, and runLightSession only pushes focus out to macOS
                // when it observes a change. So if the model and macOS have
                // drifted apart -- which happens whenever focus lands on an
                // empty workspace, since there is no window for
                // syncFocusToMacOs to focus -- focus-monitor does nothing at
                // all, and the user has to focus some other monitor first to
                // make the model disagree before coming back. An explicit
                // focus-monitor should take effect regardless of what the
                // model believes.
                focus.windowOrNil?.nativeFocus()
                return .from(bool: success)
            case .failure(let msg):
                return .fail(io.err(msg))
        }
    }
}

extension MonitorTarget {
    @MainActor func resolve(_ currentMonitor: MonitorInfo, wrapAround: Bool) -> Result<MonitorInfo, String> {
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
                let monitors = sortedMonitorInfos
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
                let monitors = sortedMonitorInfos
                guard let targetMonitor = patterns.lazy.compactMap({ $0.resolveMonitor(sortedMonitors: monitors) }).first else {
                    return .failure("None of the monitors match the pattern(s)")
                }
                return .success(targetMonitor)
        }
    }
}

extension MonitorInfo {
    func relation(to monitor: MonitorInfo) -> Orientation {
        guard let otherYRange = monitor.rect.minY.until(excl: monitor.rect.maxY) else { return .h }
        guard let myYRange = rect.minY.until(excl: rect.maxY) else { return .h }
        return myYRange.overlaps(otherYRange) ? .h : .v
    }

    func findRelativeMonitor(inDirection direction: CardinalDirection) -> (monitorsInDirection: [MonitorInfo], index: Int)? {
        let currentMonitor = self
        let monitors = sortedMonitorInfos.filter {
            currentMonitor.rect.topLeftCorner == $0.rect.topLeftCorner ||
                $0.relation(to: currentMonitor) == direction.orientation
        }
        guard let index = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else { return nil }
        return (monitors, index + direction.focusOffset)
    }
}
