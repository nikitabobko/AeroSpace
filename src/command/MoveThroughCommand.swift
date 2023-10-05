struct MoveThroughCommand: Command {
    let direction: CardinalDirection

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let currentWindow = focusedWindowOrEffectivelyFocused else { return }
        if let parent = currentWindow.parent as? TilingContainer {
            let indexOfCurrent = currentWindow.ownIndex
            let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
            if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                switch parent.children[indexOfSiblingTarget].kind {
                case .tilingContainer(let topLevelSiblingTargetContainer):
                    deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                case .window: // "swap windows"
                    let prevBinding = currentWindow.unbindFromParent()
                    currentWindow.bindTo(parent: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                case .workspace:
                    error("Impossible")
                }
            } else {
                moveOut(window: currentWindow, direction: direction)
            }
        } else if let _ = currentWindow.parent as? Workspace { // floating window
            // todo
        }
    }
}

private func moveOut(window: Window, direction: CardinalDirection) {
    let topMostChild = window.parents.first(where: {
        // todo rewrite "is Workspace" part once "sticky" is introduced
        $0.parent is Workspace || ($0.parent as? TilingContainer)?.orientation == direction.orientation
    }) as! TilingContainer
    let bindTo: TilingContainer
    let bindToIndex: Int
    switch topMostChild.parent.kind {
    case .tilingContainer(let parent):
        precondition(parent.orientation == direction.orientation)
        bindTo = parent
        bindToIndex = topMostChild.ownIndex + direction.insertionOffset
    case .workspace(let parent): // create implicit container
        let prevRoot = parent.rootTilingContainer
        prevRoot.unbindFromParent()
        precondition(prevRoot != parent.rootTilingContainer)
        parent.rootTilingContainer.orientation = direction.orientation
        parent.rootTilingContainer.layout = .List // todo force List layout for implicit containers?
        prevRoot.bindTo(parent: parent.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO)

        bindTo = parent.rootTilingContainer
        bindToIndex = direction.insertionOffset
    case .window:
        error("Window can't contain children nodes")
    }

    window.unbindFromParent()
    window.bindTo(
        parent: bindTo,
        adaptiveWeight: WEIGHT_AUTO,
        index: bindToIndex
    )
}

private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) {
    let deepTarget = container.findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget.kind {
    case .tilingContainer:
        window.unbindFromParent()
        window.bindTo(parent: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
    case .window(let deepTarget):
        window.unbindFromParent()
        window.bindTo(
            parent: (deepTarget.parent as! TilingContainer),
            adaptiveWeight: WEIGHT_AUTO,
            index: deepTarget.ownIndex + 1
        )
    case .workspace:
        error("Impossible")
    }
}

private extension TreeNode {
    func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TreeNode {
        switch kind {
        case .window:
            return self
        case .tilingContainer(let container):
            if container.orientation == orientation {
                return container
            } else {
                return (mostRecentChild ?? errorT("Empty containers must be detached during normalization"))
                    .findDeepMoveInTargetRecursive(orientation)
            }
        case .workspace:
            error("Impossible")
        }
    }
}
