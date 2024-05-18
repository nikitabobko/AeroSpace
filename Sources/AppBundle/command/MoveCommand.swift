import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let direction = args.direction.val
        guard let currentWindow = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
        }
        switch currentWindow.parent.cases {
            case .tilingContainer(let parent):
                let indexOfCurrent = currentWindow.ownIndex
                let indexOfSiblingTarget = indexOfCurrent + direction.focusOffset
                if parent.orientation == direction.orientation && parent.children.indices.contains(indexOfSiblingTarget) {
                    switch parent.children[indexOfSiblingTarget].tilingTreeNodeCasesOrThrow() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction)
                        case .window: // "swap windows"
                            let prevBinding = currentWindow.unbindFromParent()
                            currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfSiblingTarget)
                    }
                    return true
                } else {
                    return moveOut(state, window: currentWindow, direction: direction)
                }
            case .workspace: // floating window
                state.stderr.append("moving floating windows isn't yet supported") // todo
                return false
            case .macosInvisibleWindowsContainer:
                state.stderr.append(moveOutInvisibleWindow)
                return false
            case .macosFullscreenWindowsContainer:
                state.stderr.append(moveOutFullscreenWindow)
                return false
            case .macosPopupWindowsContainer:
                return false // Impossible
        }
    }
}

private let moveOutInvisibleWindow = "moving macOS invisible windows (minimized, or windows of hidden apps) isn't yet supported. This behavior is subject to change"
private let moveOutFullscreenWindow = "moving macOS fullscreen windows isn't yet supported. This behavior is subject to change"

private func moveOut(_ state: CommandMutableState, window: Window, direction: CardinalDirection) -> Bool {
    let innerMostChild = window.parents.first(where: {
        return switch $0.parent?.cases {
            case .tilingContainer(let parent): parent.orientation == direction.orientation
            // Stop searching
            case .workspace, .macosInvisibleWindowsContainer, nil, .macosFullscreenWindowsContainer,
                .macosPopupWindowsContainer: true
        }
    }) as! TilingContainer
    let bindTo: TilingContainer
    let bindToIndex: Int
    switch innerMostChild.parent.nodeCases {
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            bindTo = parent
            bindToIndex = innerMostChild.ownIndex + direction.insertionOffset
        case .workspace(let parent): // create implicit container
            let prevRoot = parent.rootTilingContainer
            prevRoot.unbindFromParent()
            // Force tiles layout
            _ = TilingContainer(parent: parent, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
            check(prevRoot != parent.rootTilingContainer)
            prevRoot.bind(to: parent.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)

            bindTo = parent.rootTilingContainer
            bindToIndex = direction.insertionOffset
        case .macosInvisibleWindowsContainer:
            state.stderr.append(moveOutInvisibleWindow)
            return false
        case .macosFullscreenWindowsContainer:
            state.stderr.append(moveOutFullscreenWindow)
            return false
        case .macosPopupWindowsContainer:
            return false // Impossible
        case .window:
            error("Window can't contain children nodes")
    }

    window.bind(
        to: bindTo,
        adaptiveWeight: WEIGHT_AUTO,
        index: bindToIndex
    )
    return true
}

private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection) {
    let deepTarget = container.tilingTreeNodeCasesOrThrow().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            window.bind(
                to: (deepTarget.parent as! TilingContainer),
                adaptiveWeight: WEIGHT_AUTO,
                index: deepTarget.ownIndex + 1
            )
    }
}

private extension TilingTreeNodeCases {
    func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TilingTreeNodeCases {
        return switch self {
            case .window:
                self
            case .tilingContainer(let container):
                if container.orientation == orientation {
                    .tilingContainer(container)
                } else {
                    (container.mostRecentChild ?? errorT("Empty containers must be detached during normalization"))
                        .tilingTreeNodeCasesOrThrow()
                        .findDeepMoveInTargetRecursive(orientation)
                }
        }
    }
}
