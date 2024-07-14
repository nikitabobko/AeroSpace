import AppKit
import Common

struct FocusCommand: Command {
    let args: FocusCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        // todo bug: floating windows break mru
        let floatingWindows = args.floatingAsTiling ? makeFloatingWindowsSeenAsTiling(workspace: focus.workspace) : []
        defer {
            if args.floatingAsTiling {
                restoreFloatingWindows(floatingWindows: floatingWindows, workspace: focus.workspace)
            }
        }

        switch args.target {
            case .direction(let direction):
                let window = focus.windowOrNil
                if let (parent, ownIndex) = window?.closestParent(hasChildrenInDirection: direction, withLayout: nil) {
                    guard let windowToFocus = parent.children[ownIndex + direction.focusOffset]
                        .findFocusTargetRecursive(snappedTo: direction.opposite) else { return false }
                    return windowToFocus.focusWindow()
                } else {
                    return hitWorkspaceBoundaries(focus, io, args, direction)
                }
            case .windowId(let windowId):
                if let windowToFocus = MacWindow.allWindowsMap[windowId] {
                    return windowToFocus.focusWindow()
                } else {
                    return io.err("Can't find window with ID \(windowId)")
                }
            case .dfsIndex(let dfsIndex):
                if let windowToFocus = focus.workspace.rootTilingContainer.allLeafWindowsRecursive.getOrNil(atIndex: Int(dfsIndex)) {
                    return windowToFocus.focusWindow()
                } else {
                    return io.err("Can't find window with DFS index \(dfsIndex)")
                }
        }
    }
}

private func hitWorkspaceBoundaries(
    _ focus: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection
) -> Bool {
    switch args.boundaries {
        case .workspace:
            return switch args.boundariesAction {
                case .stop: true
                case .wrapAroundTheWorkspace: wrapAroundTheWorkspace(focus, io, direction)
                case .wrapAroundAllMonitors: errorT("Must be discarded by args parser")
            }
        case .allMonitorsUnionFrame:
            let currentMonitor = focus.workspace.workspaceMonitor
            guard let (monitors, index) = currentMonitor.findRelativeMonitor(inDirection: direction) else {
                return io.err("Can't find monitor in direction \(direction)")
            }

            if let targetMonitor = monitors.getOrNil(atIndex: index) {
                return targetMonitor.activeWorkspace.focusWorkspace()
            } else {
                guard let wrapped = monitors.get(wrappingIndex: index) else { return false }
                return hitAllMonitorsOuterFrameBoundaries(focus, io, args, direction, wrapped)
            }
    }
}

private func hitAllMonitorsOuterFrameBoundaries(
    _ focus: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    _ wrappedMonitor: Monitor
) -> Bool {
    switch args.boundariesAction {
        case .stop:
            return true
        case .wrapAroundTheWorkspace:
            return wrapAroundTheWorkspace(focus, io, direction)
        case .wrapAroundAllMonitors:
            wrappedMonitor.activeWorkspace.findFocusTargetRecursive(snappedTo: direction.opposite)?.markAsMostRecentChild()
            return wrappedMonitor.activeWorkspace.focusWorkspace()
    }
}

private func wrapAroundTheWorkspace(_ focus: LiveFocus, _ io: CmdIo, _ direction: CardinalDirection) -> Bool {
    guard let windowToFocus = focus.workspace.findFocusTargetRecursive(snappedTo: direction.opposite) else {
        return io.err(noWindowIsFocused)
    }
    return windowToFocus.focusWindow()
}

private func makeFloatingWindowsSeenAsTiling(workspace: Workspace) -> [FloatingWindowData] {
    let mruBefore = workspace.mostRecentWindowRecursive
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    let floatingWindows: [FloatingWindowData] = workspace.floatingWindows
        .map { (window: Window) -> FloatingWindowData? in
            let center = window.getCenter() // todo bug: we shouldn't access ax api here. What if the window was moved but it wasn't committed to ax yet?
            guard let center else { return nil }
            // todo bug: what if there are no tiling windows on the workspace?
            guard let target = center.coerceIn(rect: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps).findIn(tree: workspace.rootTilingContainer, virtual: true) else { return nil }
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
    let mruBefore = workspace.mostRecentWindowRecursive
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    for floating in floatingWindows {
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
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                error("Impossible")
        }
    }
}
