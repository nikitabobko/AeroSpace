import Common

struct FocusCommand: Command {
    let info: CmdStaticInfo = FocusCmdArgs.info
    let args: FocusCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        let window = subject.windowOrNil
        let workspace = subject.workspace
        // todo bug: floating windows break mru
        let floatingWindows = makeFloatingWindowsSeenAsTiling(workspace: workspace)
        defer {
            restoreFloatingWindows(floatingWindows: floatingWindows, workspace: workspace)
        }
        let direction = args.direction

        var result: Bool = true
        if let (parent, ownIndex) = window?.closestParent(hasChildrenInDirection: direction, withLayout: nil) {
            guard let windowToFocus = parent.children[ownIndex + direction.focusOffset]
                .findFocusTargetRecursive(snappedTo: direction.opposite) else { return false }
            subject = .window(windowToFocus)
        } else {
            result = hitWorkspaceBoundaries(&subject, &stdout, args, direction) && result
        }

        switch subject {
        case .emptyWorkspace(let name):
            result = WorkspaceCommand(args: WorkspaceCmdArgs(target: .workspaceName(name: name, autoBackAndForth: false)))
                .run(&subject, &stdout) && result
        case .window(let windowToFocus):
            windowToFocus.focus()
        }
        return result
    }
}

private func hitWorkspaceBoundaries(
    _ subject: inout CommandSubject,
    _ stdout: inout [String],
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection
) -> Bool {
    switch args.boundaries {
    case .workspace:
        switch args.boundariesAction {
        case .stop:
            return true
        case .wrapAroundTheWorkspace:
            wrapAroundTheWorkspace(subject: &subject, direction)
            return true
        case .wrapAroundAllMonitors:
            error("Must be discarded by args parser")
        }
    case .allMonitorsUnionFrame:
        let currentMonitor = subject.workspace.monitor
        let monitors = sortedMonitors.filter { currentMonitor.rect.topLeftCorner == $0.rect.topLeftCorner || $0.relation(to: currentMonitor) == direction.orientation }
        guard let index = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else { return false }

        if let targetMonitor = monitors.getOrNil(atIndex: index + direction.focusOffset) {
            return targetMonitor.focus(&subject, &stdout)
        } else {
            guard let wrapped = monitors.get(wrappingIndex: index + direction.focusOffset) else { return false }
            return hitAllMonitorsOuterFrameBoundaries(&subject, &stdout, args, direction, wrapped)
        }
    }
}

private func hitAllMonitorsOuterFrameBoundaries(
    _ subject: inout CommandSubject,
    _ stdout: inout [String],
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    _ wrappedMonitor: Monitor
) -> Bool {
    switch args.boundariesAction {
    case .stop:
        return true
    case .wrapAroundTheWorkspace:
        wrapAroundTheWorkspace(subject: &subject, direction)
        return true
    case .wrapAroundAllMonitors:
        wrappedMonitor.activeWorkspace.findFocusTargetRecursive(snappedTo: direction.opposite)?.markAsMostRecentChild()
        return wrappedMonitor.focus(&subject, &stdout)
    }
}

private extension Monitor {
    func focus(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        WorkspaceCommand(args: WorkspaceCmdArgs(target: .workspaceName(name: activeWorkspace.name, autoBackAndForth: false)))
            .run(&subject, &stdout)
    }
}

private func wrapAroundTheWorkspace(subject: inout CommandSubject, _ direction: CardinalDirection) {
    guard let windowToFocus = subject.workspace.findFocusTargetRecursive(snappedTo: direction.opposite) else { return }
    subject = .window(windowToFocus)
    windowToFocus.focus()
}

private extension Monitor {
    func relation(to monitor: Monitor) -> Orientation {
        let yRange = rect.minY..<rect.maxY
        return yRange.contains(monitor.rect.minY) || yRange.contains(monitor.rect.maxY) ? .h : .v
    }
}

private func makeFloatingWindowsSeenAsTiling(workspace: Workspace) -> [FloatingWindowData] {
    let mruBefore = workspace.mostRecentWindow
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    let floatingWindows: [FloatingWindowData] = workspace.floatingWindows
        .map { (window: Window) -> FloatingWindowData? in
            guard let center = window.getCenter() else { return nil }
            // todo bug: what if there are no tiling windows on the workspace?
            guard let target = center.coerceIn(rect: window.workspace.monitor.visibleRectPaddedByOuterGaps).findIn(tree: workspace.rootTilingContainer, virtual: true) else { return nil }
            guard let targetCenter = target.getCenter() else { return nil }
            guard let tilingParent = target.parent as? TilingContainer else { return nil }
            let index = center.getProjection(tilingParent.orientation) >= targetCenter.getProjection(tilingParent.orientation)
                ? target.ownIndex + 1
                : target.ownIndex
            let data = window.unbindFromParent()
            return FloatingWindowData(window: window, center: center, parent: tilingParent, adaptiveWeight: data.adaptiveWeight, index: index)
        }
        .filterNotNil()
        .sortedBy { $0.center.getProjection($0.parent.orientation) }
        .reversed()

    for floating in floatingWindows { // Make floating windows be seen as tiling
        floating.window.bind(to: floating.parent, adaptiveWeight: 1, index: floating.index)
    }
    return floatingWindows
}

private func restoreFloatingWindows(floatingWindows: [FloatingWindowData], workspace: Workspace) {
    let mruBefore = workspace.mostRecentWindow
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    for floating in floatingWindows {
        floating.window.unbindFromParent()
        floating.window.bind(to: workspace, adaptiveWeight: floating.adaptiveWeight, index: INDEX_BIND_LAST)
    }
}

private struct FloatingWindowData {
    let window: Window
    let center: CGPoint

    let parent: TilingContainer
    let adaptiveWeight: CGFloat
    let index: Int
}

private extension TreeNode {
    func findFocusTargetRecursive(snappedTo direction: CardinalDirection) -> Window? {
        switch genericKind {
        case .workspace(let workspace):
            return workspace.rootTilingContainer.findFocusTargetRecursive(snappedTo: direction)
        case .window(let window):
            return window
        case .tilingContainer(let container):
            if direction.orientation == container.orientation {
                return (direction.isPositive ? container.children.last : container.children.first)?
                    .findFocusTargetRecursive(snappedTo: direction)
            } else {
                return mostRecentChild?.findFocusTargetRecursive(snappedTo: direction)
            }
        }
    }
}
