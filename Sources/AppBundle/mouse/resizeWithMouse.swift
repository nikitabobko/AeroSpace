import AppKit
import Common

func resizedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    if let window = data?.window, TrayMenuModel.shared.isEnabled {
        resizeWithMouseIfTheCase(window)
    }
    refreshAndLayout()
}

func resetManipulatedWithMouseIfPossible() {
    check(Thread.current.isMainThread)
    if currentlyManipulatedWithMouseWindowId != nil {
        currentlyManipulatedWithMouseWindowId = nil
        for workspace in Workspace.all {
            workspace.resetResizeWeightBeforeResizeRecursive()
        }
        refreshAndLayout()
    }
}

private let adaptiveWeightBeforeResizeWithMouseKey = TreeNodeUserDataKey<CGFloat>(key: "adaptiveWeightBeforeResizeWithMouseKey")

private func resizeWithMouseIfTheCase(_ window: Window) { // todo cover with tests
    if window.isHiddenViaEmulation || // Don't allow to resize windows of hidden workspaces
           !isLeftMouseButtonPressed ||
           currentlyManipulatedWithMouseWindowId != nil && window.windowId != currentlyManipulatedWithMouseWindowId ||
           getNativeFocusedWindow(startup: false) != window {
        return
    }
    switch window.parent.cases {
        case .workspace, .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer:
            return // Nothing to do for floating, invisible, or fullscreen windows
        case .tilingContainer:
            guard let rect = window.getRect() else { return }
            guard let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect else { return }
            let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left, withLayout: .tiles) ?? (nil, nil)
            let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down, withLayout: .tiles) ?? (nil, nil)
            let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up, withLayout: .tiles) ?? (nil, nil)
            let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right, withLayout: .tiles) ?? (nil, nil)
            let table: [(CGFloat, TilingContainer?, Int?, Int?)] = [
                (lastAppliedLayoutRect.minX - rect.minX, lParent, 0,                          lOwnIndex),               // Horizontal, to the left of the window
                (rect.maxY - lastAppliedLayoutRect.maxY, dParent, dOwnIndex?.lets { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
                (lastAppliedLayoutRect.minY - rect.minY, uParent, 0,                          uOwnIndex),               // Vertical, to the up of the window
                (rect.maxX - lastAppliedLayoutRect.maxX, rParent, rOwnIndex?.lets { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
            ]
            for (diff, parent, startIndex, pastTheEndIndex) in table {
                if let parent, let startIndex, let pastTheEndIndex, pastTheEndIndex - startIndex > 0 && abs(diff) > 5 { // 5 pixels should be enough to fight with accumulated floating precision error
                    let siblingDiff = diff.div(pastTheEndIndex - startIndex)!
                    let orientation = parent.orientation

                    window.parentsWithSelf.lazy
                        .prefix(while: { $0 != parent })
                        .filter {
                            let parent = $0.parent as? TilingContainer
                            return parent?.orientation == orientation && parent?.layout == .tiles
                        }
                        .forEach { $0.setWeight(orientation, $0.getWeightBeforeResize(orientation) + diff) }
                    for sibling in parent.children[startIndex..<pastTheEndIndex] {
                        sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - siblingDiff)
                    }
                }
            }
            currentlyManipulatedWithMouseWindowId = window.windowId
    }
}

private extension TreeNode {
    func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        let currentWeight = getWeight(orientation) // Check assertions
        return getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? (lastAppliedLayoutVirtualRect?.getDimension(orientation) ?? currentWeight)
            .also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    func resetResizeWeightBeforeResizeRecursive() {
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
