struct MoveThroughCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        if let parent = currentWindow.parent as? TilingContainer {
            let indexOfCurrent = currentWindow.ownIndex
            let indexOfSiblingTarget = direction.isPositive ? indexOfCurrent + 1 : indexOfCurrent - 1
            if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                switch parent.children[indexOfSiblingTarget].kind {
                case .tilingContainer(let topLevelSiblingTargetContainer):
                    deepMove(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                case .window: // "swap windows"
                    let prevBinding = currentWindow.unbindFromParent()
                    currentWindow.bindTo(parent: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                case .workspace:
                    error("Impossible")
                }
            } else { // "move out"

            }
        } else if let _ = currentWindow.parent as? Workspace { // floating window
            // todo
        }
    }
}

private func deepMove(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) {
    let mruIndexMap = window.workspace.mruWindows.mruIndexMap
    let preferredPath: [TreeNode] = container.allLeafWindowsRecursive
        .minBy { mruIndexMap[$0] ?? Int.max }!
        .parentsWithSelf
        .reversed()
        .drop(while: { $0 != container })
        .dropFirst()
        .toArray()
    let deepTarget = container.findContainerWithOrientOrPreferredPath(moveDirection.orientation, preferredPath)
    switch deepTarget.kind {
    case .tilingContainer:
        window.unbindFromParent()
        window.bindTo(parent: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
    case .window(let target):
        window.unbindFromParent()
        window.bindTo(
            parent: (target.parent as! TilingContainer),
            adaptiveWeight: WEIGHT_AUTO,
            index: target.ownIndex + 1
        )
    case .workspace:
        error("Impossible")
    }
}

private extension TreeNode {
    func findContainerWithOrientOrPreferredPath(_ orientation: Orientation, _ preferredPath: [TreeNode]) -> TreeNode {
        switch kind {
        case .window:
            return self
        case .tilingContainer(let container):
            if container.orientation == orientation {
                return container
            } else {
                assert(children.contains(preferredPath.first!))
                return preferredPath.first!
                    .findContainerWithOrientOrPreferredPath(orientation, Array(preferredPath.dropFirst()))
            }
        case .workspace:
            error("Impossible")
        }
    }
}
