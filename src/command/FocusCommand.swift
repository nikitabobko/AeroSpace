struct FocusCommand: Command {
    let direction: CardinalDirection

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        let workspace = currentWindow.workspace
        let floatingWindows = makeFloatingWindowsSeenAsTiling(workspace: workspace)
        defer {
            restoreFloatingWindows(floatingWindows: floatingWindows, workspace: workspace)
        }

        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else { return }
        let windowToFocus = parent.children[ownIndex + direction.focusOffset]
            .findFocusTargetRecursive(snappedTo: direction.opposite)

        windowToFocus?.focus()
    }
}

private func makeFloatingWindowsSeenAsTiling(workspace: Workspace) -> [FloatingWindowData] {
    let floatingWindows: [FloatingWindowData] = workspace.floatingWindows
        .map { (window: Window) -> FloatingWindowData? in
            guard let center = window.getCenter() else { return nil }
            guard let target = center.coerceIn(rect: window.workspace.monitor.rect).findIn(tree: workspace.rootTilingContainer) else { return nil }
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
