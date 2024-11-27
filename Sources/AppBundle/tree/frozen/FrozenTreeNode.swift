import AppKit
import Common

enum FrozenTreeNode {
    case container(FrozenContainer)
    case window(FrozenWindow)
}

struct FrozenContainer {
    let children: [FrozenTreeNode]
    let layout: Layout
    let orientation: Orientation
    let weight: CGFloat

    init(_ container: TilingContainer) {
        children = container.children.map {
            switch $0.nodeCases {
                case .window(let w): .window(FrozenWindow(w))
                case .tilingContainer(let c): .container(FrozenContainer(c))
                case .workspace,
                     .macosMinimizedWindowsContainer,
                     .macosHiddenAppsWindowsContainer,
                     .macosFullscreenWindowsContainer,
                     .macosPopupWindowsContainer:
                    illegalChildParentRelation(child: $0, parent: container)
            }
        }
        layout = container.layout
        orientation = container.orientation
        weight = getWeightOrNil(container) ?? 1
    }
}

struct FrozenWindow {
    let id: UInt32
    let weight: CGFloat

    init(_ window: Window) {
        id = window.windowId
        weight = getWeightOrNil(window) ?? 1
    }
}

private func getWeightOrNil(_ node: TreeNode) -> CGFloat? {
    ((node.parent as? TilingContainer)?.orientation).map { node.getWeight($0) }
}
