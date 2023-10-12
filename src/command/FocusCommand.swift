struct FocusCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        guard let (parent, ownIndex) = currentWindow.closestParent(hasChildrenInDirection: direction, withLayout: nil) else { return }
        let windowToFocus = parent.children[ownIndex + direction.focusOffset]
            .findFocusTargetRecursive(snappedTo: direction.opposite)

        windowToFocus?.focus()
    }
}

private extension TreeNode {
    func findFocusTargetRecursive(snappedTo direction: CardinalDirection) -> Window? {
        switch kind {
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
