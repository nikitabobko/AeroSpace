import Common

struct FocusCommand: Command {
    let args: FocusCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let window = state.subject.windowOrNil
        let workspace = state.subject.workspace
        // todo bug: floating windows break mru
        let floatingWindows = makeFloatingWindowsSeenAsTiling(workspace: workspace)
        defer {
            restoreFloatingWindows(floatingWindows: floatingWindows, workspace: workspace)
        }
        let direction = args.direction.val

        var result: Bool = true
        if let (parent, ownIndex) = window?.closestParent(hasChildrenInDirection: direction, withLayout: nil) {
            guard let windowToFocus = parent.children[ownIndex + direction.focusOffset]
                .findFocusTargetRecursive(snappedTo: direction.opposite) else { return false }
            state.subject = .window(windowToFocus)
        } else {
            result = hitWorkspaceBoundaries(state, args, direction) && result
        }

        switch state.subject {
        case .emptyWorkspace(let name):
            result = WorkspaceCommand.run(state, name) && result
        case .window(let windowToFocus):
            windowToFocus.focus()
        }
        return result
    }
}

private func hitWorkspaceBoundaries(
    _ state: CommandMutableState,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection
) -> Bool {
    switch args.boundaries {
    case .workspace:
        switch args.boundariesAction {
        case .stop:
            return true
        case .wrapAroundTheWorkspace:
            wrapAroundTheWorkspace(state, direction)
            return true
        case .wrapAroundAllMonitors:
            error("Must be discarded by args parser")
        }
    case .allMonitorsUnionFrame:
        let currentMonitor = state.subject.workspace.monitor
        let monitors = sortedMonitors.filter { currentMonitor.rect.topLeftCorner == $0.rect.topLeftCorner || $0.relation(to: currentMonitor) == direction.orientation }
        guard let index = monitors.firstIndex(where: { $0.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }) else { return false }

        if let targetMonitor = monitors.getOrNil(atIndex: index + direction.focusOffset) {
            return targetMonitor.focus(state)
        } else {
            guard let wrapped = monitors.get(wrappingIndex: index + direction.focusOffset) else { return false }
            return hitAllMonitorsOuterFrameBoundaries(state, args, direction, wrapped)
        }
    }
}

private func hitAllMonitorsOuterFrameBoundaries(
    _ state: CommandMutableState,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    _ wrappedMonitor: Monitor
) -> Bool {
    switch args.boundariesAction {
    case .stop:
        return true
    case .wrapAroundTheWorkspace:
        wrapAroundTheWorkspace(state, direction)
        return true
    case .wrapAroundAllMonitors:
        wrappedMonitor.activeWorkspace.findFocusTargetRecursive(snappedTo: direction.opposite)?.markAsMostRecentChild()
        return wrappedMonitor.focus(state)
    }
}

private extension Monitor {
    func focus(_ state: CommandMutableState) -> Bool {
        WorkspaceCommand.run(state, activeWorkspace.name)
    }
}

private func wrapAroundTheWorkspace(_ state: CommandMutableState, _ direction: CardinalDirection) {
    guard let windowToFocus = state.subject.workspace.findFocusTargetRecursive(snappedTo: direction.opposite) else { return }
    state.subject = .window(windowToFocus)
    windowToFocus.focus()
}

private extension Monitor {
    func relation(to monitor: Monitor) -> Orientation {
        (rect.minY..<rect.maxY).overlaps(monitor.rect.minY..<monitor.rect.maxY) ? .h : .v
    }
}

private func makeFloatingWindowsSeenAsTiling(workspace: Workspace) -> [FloatingWindowData] {
    let mruBefore = workspace.mostRecentWindow
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    let floatingWindows: [FloatingWindowData] = workspace.floatingAndMacosFullscreenWindows
        .map { (window: Window) -> FloatingWindowData? in
            let center = window.isMacosFullscreen ? workspace.monitor.rect.topLeftCorner : window.getCenter()
            guard let center else { return nil }
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
        switch nodeCases {
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
        case .macosInvisibleWindowsContainer:
            error("Impossible")
        }
    }
}
