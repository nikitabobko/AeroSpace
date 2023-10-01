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
            guard let index = topMostChild.ownIndexOrNil else { return }
            let mruIndexMap = currentWindow.workspace.mruWindows.mruIndexMap
            let windowToFocus: Window? = parent.children
                .getOrNil(atIndex: index + direction.offset)?
                .allLeafWindowsRecursive(snappedTo: direction.opposite)
                .minBy { mruIndexMap[$0] ?? Int.max }
            windowToFocus?.focus()
        } else {
            // todo direction == .child || direction == .parent
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
