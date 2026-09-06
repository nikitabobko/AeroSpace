import AppKit
import Common

final class TilingContainer: TreeNode, NonLeafTreeNodeObject { // todo consider renaming to GenericContainer
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    var layout: Layout
    private var _scrollingIndex: Int = 0
    var scrollingIndex: Int {
        get { _scrollingIndex }
        set { _scrollingIndex = max(0, newValue) }
    }

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = orientation
        self.layout = layout
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .tiles, index: index)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .v, .tiles, index: index)
    }
}

extension TilingContainer {
    var isRootContainer: Bool { parent is Workspace }
    var isScrollingRoot: Bool { isRootContainer && layout == .scrolling }

    var maxScrollingIndex: Int { max(0, children.count - 2) }

    func clampScrollingIndex() {
        scrollingIndex = isScrollingRoot ? min(scrollingIndex, maxScrollingIndex) : 0
    }

    @MainActor
    func reveal(_ window: Window?, preferRightPane: Bool) {
        guard isScrollingRoot else { return }
        guard let index = window.flatMap(scrollingPageIndex(for:)) else {
            clampScrollingIndex()
            return
        }
        scrollingIndex = preferRightPane
            ? min(max(0, index - 1), maxScrollingIndex)
            : min(
                max(
                    0,
                    index < scrollingIndex
                        ? index
                        : (index > scrollingIndex + 1 ? index - 1 : scrollingIndex),
                ),
                maxScrollingIndex,
            )
    }

    @MainActor
    func scroll(in direction: CardinalDirection) -> Window? {
        guard isScrollingRoot else { return nil }
        switch direction {
            case .left:
                let nextIndex = max(0, scrollingIndex - 1)
                scrollingIndex = nextIndex
                return children.getOrNil(atIndex: nextIndex)?.findLeafWindowRecursive(snappedTo: .left)
            case .right:
                let nextIndex = min(maxScrollingIndex, scrollingIndex + 1)
                scrollingIndex = nextIndex
                return children.getOrNil(atIndex: nextIndex + 1)?.findLeafWindowRecursive(snappedTo: .right)
            case .up, .down:
                return nil
        }
    }

    @MainActor
    private func scrollingPageIndex(for window: Window) -> Int? {
        window.parentsWithSelf.first(where: { $0.parent === self })?.ownIndex
    }

    @MainActor
    func changeOrientation(_ targetOrientation: Orientation) {
        if orientation == targetOrientation {
            return
        }
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            var orientation = targetOrientation
            parentsWithSelf
                .filterIsInstance(of: TilingContainer.self)
                .forEach {
                    $0._orientation = orientation
                    orientation = orientation.opposite
                }
        } else {
            _orientation = targetOrientation
        }
    }

    func normalizeOppositeOrientationForNestedContainers() {
        if orientation == (parent as? TilingContainer)?.orientation {
            _orientation = orientation.opposite
        }
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

enum Layout: String {
    case tiles
    case accordion
    case scrolling
    case tabs
}

extension String {
    func parseLayout() -> Layout? {
        switch Layout(rawValue: self) {
            case let parsed?: parsed
            case nil where self == "list": .tiles
            case nil: nil
        }
    }
}
