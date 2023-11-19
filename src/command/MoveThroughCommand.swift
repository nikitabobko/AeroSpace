struct MoveThroughCommand: Command {
    let direction: CardinalDirection

    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        guard let currentWindow = state.window else { return }
        switch currentWindow.parent.kind {
        case .tilingContainer(let parent):
            let indexOfCurrent = currentWindow.ownIndex
            let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
            if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                switch parent.children[indexOfSiblingTarget].genericKind {
                case .tilingContainer(let topLevelSiblingTargetContainer):
                    deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                case .window: // "swap windows"
                    let prevBinding = currentWindow.unbindFromParent()
                    currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                case .workspace:
                    error("Impossible")
                }
            } else {
                moveOut(window: currentWindow, direction: direction)
            }
        case .workspace: // floating window
            break // todo support moving floating windows
        }
    }
}

private func moveOut(window: Window, direction: CardinalDirection) {
    let innerMostChild = window.parents.first(where: {
        switch $0.parent?.kind {
        case .workspace, nil:
            return true // Stop searching
        case .tilingContainer(let parent):
            return parent.orientation == direction.orientation
        }
    }) as! TilingContainer
    let bindTo: TilingContainer
    let bindToIndex: Int
    switch innerMostChild.parent.genericKind {
    case .tilingContainer(let parent):
        check(parent.orientation == direction.orientation)
        bindTo = parent
        bindToIndex = innerMostChild.ownIndex + direction.insertionOffset
    case .workspace(let parent): // create implicit container
        let prevRoot = parent.rootTilingContainer
        prevRoot.unbindFromParent()
        // Force list layout
        _ = TilingContainer(parent: parent, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
        check(prevRoot != parent.rootTilingContainer)
        prevRoot.bind(to: parent.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)

        bindTo = parent.rootTilingContainer
        bindToIndex = direction.insertionOffset
    case .window:
        error("Window can't contain children nodes")
    }

    window.unbindFromParent()
    window.bind(
        to: bindTo,
        adaptiveWeight: WEIGHT_AUTO,
        index: bindToIndex
    )
}

private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) {
    let deepTarget = container.findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget.genericKind {
    case .tilingContainer(let deepTarget):
        window.unbindFromParent()
        window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
    case .window(let deepTarget):
        window.unbindFromParent()
        window.bind(
            to: (deepTarget.parent as! TilingContainer),
            adaptiveWeight: WEIGHT_AUTO,
            index: deepTarget.ownIndex + 1
        )
    case .workspace:
        error("Impossible")
    }
}

private extension TreeNode {
    func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TreeNode {
        switch genericKind {
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
