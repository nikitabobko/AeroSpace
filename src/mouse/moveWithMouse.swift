func movedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    if let window = data?.window, TrayMenuModel.shared.isEnabled {
        moveWithMouseIfTheCase(window)
    }
    refreshAndLayout()
}

private func moveWithMouseIfTheCase(_ window: Window) { // todo cover with tests
    if window.isHiddenViaEmulation || // Don't allow to move windows of hidden workspaces
           getNativeFocusedWindow(startup: false) != window ||
           !isLeftMouseButtonPressed ||
           currentlyManipulatedWithMouseWindowId != nil && window.windowId != currentlyManipulatedWithMouseWindowId {
        return
    }
    switch window.parent.kind {
    case .workspace:
        moveFloatingWindow(window)
    case .tilingContainer:
        moveTilingWindow(window)
    }
}

private func moveFloatingWindow(_ window: Window) {
    guard let targetWorkspace = window.getCenter()?.monitorApproximation.activeWorkspace else { return }
    if targetWorkspace != window.parent {
        window.unbindFromParent()
        window.bindAsFloatingWindow(to: targetWorkspace)
    }
}

private func moveTilingWindow(_ window: Window) {
    currentlyManipulatedWithMouseWindowId = window.windowId
    window.lastAppliedLayoutTilingRectForMouse = nil
    let mouseLocation = mouseLocation
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    let swapTarget = mouseLocation.findIn(tree: targetWorkspace.workspace.rootTilingContainer)?.takeIf({ $0 != window })
    if targetWorkspace != window.workspace { // Move window to a different monitor
        let index: Int
        if let swapTarget, let parent = swapTarget.parent as? TilingContainer, let targetRect = swapTarget.lastAppliedLayoutTilingRectForMouse {
            index = mouseLocation.getProjection(parent.orientation) >= targetRect.center.getProjection(parent.orientation)
                ? swapTarget.ownIndex + 1
                : swapTarget.ownIndex
        } else {
            index = 0
        }
        window.unbindFromParent()
        window.bind(
            to: swapTarget?.parent ?? targetWorkspace.rootTilingContainer,
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

        window2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
        window1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
    } else {
        let binding1 = window1.unbindFromParent()
        let binding2 = window2.unbindFromParent()

        window1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
        window2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
    }
}

extension CGPoint {
    func findIn(tree: TilingContainer) -> Window? {
        let point = self
        let target: TreeNode?
        switch tree.layout {
        case .tiles:
            target = tree.children.first(where: { $0.lastAppliedLayoutTilingRectForMouse?.contains(point) == true })
        case .accordion:
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
