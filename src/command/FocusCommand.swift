struct FocusCommand: Command { // todo speed up. Now it's slightly slow (probably because of refresh)
    let direction: Direction

    enum Direction: String {
        case up, down, left, right

        case parent, child //, floating, tiling, toggle_tiling_floating // not needed

        // todo support only if asked
        //case next, prev
    }

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        if let direction = direction.cardinalOrNil {
            let topMostChild = currentWindow.parentsWithSelf.first(where: {
                // todo rewrite "is Workspace" part once "sticky" is introduced
                $0.parent is Workspace || ($0.parent as? TilingContainer)?.orientation == direction.orientation
            })!
            guard let parent = topMostChild.parent as? TilingContainer else { return }
            precondition(parent.orientation == direction.orientation)
            let windowToFocus = parent.children
                .getOrNil(atIndex: topMostChild.ownIndexOrNil! + direction.focusOffset)?
                .findFocusTargetRecursive(snappedTo: direction.opposite)

            windowToFocus?.focus()
        } else {
            // todo direction == .child || direction == .parent
        }
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

extension FocusCommand.Direction {
    var cardinalOrNil: CardinalDirection? {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .parent:
            return nil
        case .child:
            return nil
        }
    }
}
