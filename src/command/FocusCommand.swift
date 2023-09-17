struct FocusCommand: Command {
    let direction: Direction

    enum Direction: String {
        case up, down, left, right

        case parent, child //, floating, tiling, toggle_tiling_floating // not needed

        // todo support only if asked
        //case next, prev
    }

    func run() async {
        precondition(Thread.current.isMainThread)
        guard let window = NSWorkspace.focusedApp?.macApp?.focusedWindow ?? Workspace.focused.mruWindows.mostRecent else { return }
        if let direction = direction.cardinalOrNil {
            let orientation = direction.orientation
            guard let topMostChild = window.parentsWithSelf.first(where: {
                $0.parent is Workspace || ($0.parent as? TilingContainer)?.orientation == orientation
            }) else { return }
            guard let parent = topMostChild.parent as? TilingContainer else { return }
            guard let index = parent.children.firstIndex(of: topMostChild) else { return }
            let mruIndexMap = window.workspace.mruWindows.mruIndexMap
            let window: MacWindow? = parent.children.getOrNil(atIndex: direction.isPositive ? index + 1 : index - 1)?
                .allLeafWindowsRecursive(snappedTo: direction.opposite)
                .minBy { mruIndexMap[$0] ?? Int.max }
            window?.focus()
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