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
        guard let lastAppliedLayoutRect = window.lastAppliedLayoutRect else { return }
        let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left, withLayout: .List) ?? (nil, nil)
        let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down, withLayout: .List) ?? (nil, nil)
        let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up, withLayout: .List) ?? (nil, nil)
        let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right, withLayout: .List) ?? (nil, nil)
        let table: [(CGFloat, TilingContainer?, Int?, Int?)] = [
            (lastAppliedLayoutRect.minX - rect.minX, lParent, 0,                          lOwnIndex),               // Horizontal, to the left of the window
            (rect.maxY - lastAppliedLayoutRect.maxY, dParent, dOwnIndex?.lets { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
            (lastAppliedLayoutRect.minY - rect.minY, uParent, 0,                          uOwnIndex),               // Vertical, to the up of the window
            (rect.maxX - lastAppliedLayoutRect.maxX, rParent, rOwnIndex?.lets { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
        ]
        for (diff, parent, startIndex, pastTheEndIndex) in table {
            if let parent, let startIndex, let pastTheEndIndex, pastTheEndIndex - startIndex > 0 && abs(diff) > EPS {
                let siblingDiff = diff.div(pastTheEndIndex - startIndex)!
                let orientation = parent.orientation

                window.parentsWithSelf.lazy
                    .prefix(while: { $0 != parent })
                    .filter {
                        let parent = $0.parent as? TilingContainer
                        return parent?.orientation == orientation && parent?.layout == .List
                    }
                    .forEach { $0.setWeight(orientation, $0.getWeightBeforeResize(orientation) + diff) }
                for sibling in parent.children[startIndex..<pastTheEndIndex] {
                    sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - siblingDiff)
                }
            }
        }
        currentlyResizedWithMouseWindowId = window.windowId
    }
}

private extension TreeNode {
    func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        let currentWeight = getWeight(orientation) // Check preconditions
        return getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? (lastAppliedLayoutRect?.getDimension(orientation) ?? currentWeight)
            .also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    func resetResizeWeightBeforeResizeRecursive() {
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
