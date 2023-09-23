struct FocusCommand: Command {
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
            guard let topMostChild = currentWindow.parentsWithSelf.first(where: {
                $0.parent is Workspace || ($0.parent as? TilingContainer)?.orientation == direction.orientation
            }) else { return }
            guard let parent = topMostChild.parent as? TilingContainer else { return }
            guard let index = parent.children.firstIndex(of: topMostChild) else { return }
            let mruIndexMap = currentWindow.workspace.mruWindows.mruIndexMap
            let windowToFocus: Window? = parent.children
                .getOrNil(atIndex: direction.isPositive ? index + 1 : index - 1)?
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
