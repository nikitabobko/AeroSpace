func movedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    if let window = data?.window, TrayMenuModel.shared.isEnabled {
        moveWithMouseIfTheCase(window)
    }
    refreshAndLayout()
}

private func moveWithMouseIfTheCase(_ window: Window) { // todo cover with tests
    if window.isHiddenViaEmulation || // Don't allow to move windows of hidden workspaces
           !isLeftMouseButtonPressed ||
           currentlyManipulatedWithMouseWindowId != nil && window.windowId != currentlyManipulatedWithMouseWindowId ||
           getNativeFocusedWindow(startup: false) != window {
        return
    }
    switch window.parent.cases {
    case .workspace:
        moveFloatingWindow(window)
    case .tilingContainer:
        moveTilingWindow(window)
    case .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer:
        return // Invisible and fullscreen windows can't be moved with mouse
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
    window.lastAppliedLayoutPhysicalRect = nil
    let mouseLocation = mouseLocation
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    let swapTarget = mouseLocation.findIn(tree: targetWorkspace.rootTilingContainer, virtual: false)?.takeIf({ $0 != window })
    if targetWorkspace != window.workspace { // Move window to a different monitor
        let index: Int
        if let swapTarget, let parent = swapTarget.parent as? TilingContainer, let targetRect = swapTarget.lastAppliedLayoutPhysicalRect {
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
    window.focus() // Keep the window focused
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
    func findIn(tree: TilingContainer, virtual: Bool) -> Window? {
        let point = self
        let target: TreeNode?
        switch tree.layout {
        case .tiles:
            target = tree.children.first(where: {
                (virtual ? $0.lastAppliedLayoutVirtualRect : $0.lastAppliedLayoutPhysicalRect)?.contains(point) == true
            })
        case .accordion:
            target = tree.mostRecentChild
        }
        guard let target else { return nil }
        switch target.tilingTreeNodeCasesOrThrow() {
        case .window(let window):
            return window
        case .tilingContainer(let container):
            return findIn(tree: container, virtual: virtual)
        }
    }
}
