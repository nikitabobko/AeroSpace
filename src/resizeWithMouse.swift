func resizedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    if let window = data?.window {
        resizeWithMouseIfTheCase(window)
    }
    refresh()
}

func resetResizeWithMouseIfPossible() {
    precondition(Thread.current.isMainThread)
    if currentlyResizedWithMouseWindowId != nil {
        currentlyResizedWithMouseWindowId = nil
        for workspace in Workspace.all {
            workspace.resetResizeWeightBeforeResizeRecursive()
        }
        refresh()
    }
}

var currentlyResizedWithMouseWindowId: UInt32? = nil

private let adaptiveWeightBeforeResizeWithMouseKey = TreeNodeUserDataKey<CGFloat>(key: "adaptiveWeightBeforeResizeWithMouseKey")

private func resizeWithMouseIfTheCase(_ window: MacWindow) {
    if window.workspace != Workspace.focused {
        return // Don't allow to resize windows of hidden workspaces
    }
    if focusedWindow != window {
        return
    }
    if NSEvent.pressedMouseButtons != 1 { // If mouse left button isn't pressed
        return
    }
    switch window.parent.kind {
    case .window:
        windowsCantHaveChildren()
    case .workspace:
        return // Nothing to do for floating windows
    case .tilingContainer:
        guard let rect = window.getRect() else { return }
        guard let lastLayoutedRect = window.lastLayoutedRect else { return }
        let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left) ?? (nil, nil)
        let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down) ?? (nil, nil)
        let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up) ?? (nil, nil)
        let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right) ?? (nil, nil)
        let table: [(CGFloat, TilingContainer?, Int?, Int?, Int?)] = [
            (lastLayoutedRect.minX - rect.minX, lParent, lOwnIndex, 0,                        lOwnIndex),               // Horizontal, to the left of the window
            (rect.maxY - lastLayoutedRect.maxY, dParent, dOwnIndex, dOwnIndex.map { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
            (lastLayoutedRect.minY - rect.minY, uParent, uOwnIndex, 0,                        uOwnIndex),               // Vertical, to the up of the window
            (rect.maxX - lastLayoutedRect.maxX, rParent, rOwnIndex, rOwnIndex.map { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
        ]
        for (diff, parent, ownIndex, startIndex, endIndexExclusive) in table {
            if let parent, let ownIndex, let startIndex, let endIndexExclusive, let child = parent.children.getOrNil(atIndex: ownIndex),
               endIndexExclusive - startIndex > 0 && abs(diff) > EPS {
                let delta = diff.div(endIndexExclusive - startIndex)!
                let orientation = parent.orientation

                child.setWeight(orientation, child.getWeightBeforeResize(orientation) + diff)
                for sibling in parent.children[startIndex..<endIndexExclusive] {
                    sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - delta)
                }
            }
        }
        currentlyResizedWithMouseWindowId = window.windowId
    }
}

private extension TreeNode {
    func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? getWeight(orientation).also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    func resetResizeWeightBeforeResizeRecursive() {
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
