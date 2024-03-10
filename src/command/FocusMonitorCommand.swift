import Common

struct FocusMonitorCommand: Command {
    let args: FocusMonitorCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let currentMonitor = state.subject.workspace.workspaceMonitor
        switch args.target.val {
        case .directional(let direction):
            guard let (monitorsInDirection, index) = currentMonitor.findRelativeMonitor(inDirection: direction) else {
                state.stderr.append("Can't find monitors in direction \(direction)")
                return false
            }
            let targetMonitor = args.wrapAround ? monitorsInDirection.get(wrappingIndex: index) : monitorsInDirection.getOrNil(atIndex: index)
            guard let targetMonitor else {
                state.stderr.append("No monitors in direction \(direction)")
                return false
            }
            return WorkspaceCommand.run(state, targetMonitor.activeWorkspace.name)
        case .relative(let isNext):
            let monitors = sortedMonitors
            guard let curIndex = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else {
                state.stderr.append("Can't find current monitor")
                return false
            }
            let targetIndex = isNext ? curIndex + 1 : curIndex - 1
            let targetMonitor = args.wrapAround ? monitors.get(wrappingIndex: targetIndex) : monitors.getOrNil(atIndex: targetIndex)
            guard let targetMonitor else {
                state.stderr.append("Can't find target monitor")
                return false
            }
            return WorkspaceCommand.run(state, targetMonitor.activeWorkspace.name)
        case .patterns(let patterns):
            let monitors = sortedMonitors
            guard let targetMonitor = patterns.lazy.compactMap({ $0.resolveMonitor(sortedMonitors: monitors) }).first else {
                state.stderr.append("None of the monitors match the pattern/patterns")
                return false
            }
            return WorkspaceCommand.run(state, targetMonitor.activeWorkspace.name)
        }
    }
}

extension Monitor {
    func relation(to monitor: Monitor) -> Orientation {
        (rect.minY..<rect.maxY).overlaps(monitor.rect.minY..<monitor.rect.maxY) ? .h : .v
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
