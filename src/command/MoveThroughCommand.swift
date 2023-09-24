struct MoveThroughCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        if let parent = currentWindow.parent as? TilingContainer {
            let indexOfCurrent = parent.children.firstIndex(of: currentWindow) ?? errorT("Can't find child")
            let indexOfTarget = direction.isPositive ? indexOfCurrent + 1 : indexOfCurrent - 1
            if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfTarget) {
                if let targetContainer = parent.children[indexOfTarget] as? TilingContainer { // "move in"
                    let mruIndexMap = currentWindow.workspace.mruWindows.mruIndexMap
                    let recursive = targetContainer.allLeafWindowsRecursive
                    let reversed = recursive.minBy { mruIndexMap[$0] ?? Int.max }!
                        .parentsWithSelf
                        .reversed()
                    let preferredPath: [TreeNode] = Array(Array(Array(reversed).drop(while: { $0 != targetContainer })).dropFirst())
                    let pizdets = targetContainer.findNodeOrientRecursive(direction.orientation, preferredPath)
                    if pizdets is TilingContainer {
                        currentWindow.unbindFromParent()
                        currentWindow.bindTo(parent: pizdets, adaptiveWeight: 1, index: 0) // todo adaptiveWeight
                    } else if pizdets is Window {
                        currentWindow.unbindFromParent()
                        currentWindow.bindTo(parent: (pizdets.parent as! TilingContainer), adaptiveWeight: 1,
                             index: pizdets.parent!.children.firstIndex(of: pizdets)! + 1) // todo mess
                    } else {
                        error("Impossible")
                    }
                } else if parent.children[indexOfTarget] is Window {
                    let prevBinding = currentWindow.unbindFromParent()
                    currentWindow.bindTo(parent: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfTarget)
                } else {
                    error("Impossible")
                }
            } else { // "move out"

            }
        } else if let _ = currentWindow.parent as? Workspace { // floating window
            // todo
        }
    }
}

private extension TreeNode {
    func findNodeOrientRecursive(_ orientation: Orientation, _ preferredPath: [TreeNode]) -> TreeNode {
        if let window = self as? Window {
            return window
        } else if let container = self as? TilingContainer {
            if container.orientation == orientation {
                return container
            } else {
                assert(children.contains(preferredPath.first!))
                return preferredPath.first!
                    .findNodeOrientRecursive(orientation, Array(preferredPath.dropFirst()))
            }
        } else {
            error("Impossible")
        }
    }
}