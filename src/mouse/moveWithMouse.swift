func movedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    if let window = data?.window {
        moveWithMouseIfTheCase(window)
    }
    refresh()
}

private func moveWithMouseIfTheCase(_ window: Window) { // todo cover with tests
    if window.isHiddenViaEmulation || // Don't allow to move windows of hidden workspaces
           focusedWindow != window ||
           !isLeftMouseButtonPressed ||
           currentlyManipulatedWithMouseWindowId != nil && window.windowId != currentlyManipulatedWithMouseWindowId {
        return
    }
    if !(window.parent is TilingContainer) {
        return
    }
    currentlyManipulatedWithMouseWindowId = window.windowId
    window.lastAppliedLayoutRect = nil
    let mouseLocation = mouseLocation
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    let swapTarget = mouseLocation.findIn(tree: targetWorkspace.workspace.rootTilingContainer)?.takeIf({ $0 != window })
    if targetWorkspace != window.workspace { // Move window to a different display
        let index: Int
        if let swapTarget, let parent = swapTarget.parent as? TilingContainer, let targetRect = swapTarget.lastAppliedLayoutRect {
            index = mouseLocation.getCoordinate(parent.orientation) >= targetRect.center.getCoordinate(parent.orientation)
                ? swapTarget.ownIndex + 1
                : swapTarget.ownIndex
        } else {
            index = 0
        }
        window.unbindFromParent()
        window.bindTo(
            parent: swapTarget?.parent ?? targetWorkspace.rootTilingContainer,
            adaptiveWeight: WEIGHT_AUTO,
            index: index
        )
    } else if let swapTarget {
        swapWindows(window, swapTarget)
    }
}

func swapWindows(_ window1: Window, _ window2: Window) {
    if window1 == window2 { return }

    if window1.ownIndex < window2.ownIndex {
        let binding2 = window2.unbindFromParent()
        let binding1 = window1.unbindFromParent()

        window2.bindTo(parent: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
        window1.bindTo(parent: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
    } else {
        let binding1 = window1.unbindFromParent()
        let binding2 = window2.unbindFromParent()

        window1.bindTo(parent: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
        window2.bindTo(parent: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
    }
}

private extension CGPoint {
    func findIn(tree: TilingContainer) -> Window? {
        let point = self
        let target: TreeNode?
        switch tree.layout {
        case .List:
            target = tree.children.first(where: { $0.lastAppliedLayoutRect?.contains(point) == true })
        case .Accordion:
            target = tree.mostRecentChild
        }
        switch target?.genericKind {
        case nil, .workspace:
            return nil
        case .window(let window):
            return window
        case .tilingContainer(let container):
            return findIn(tree: container)
        }
    }
}
