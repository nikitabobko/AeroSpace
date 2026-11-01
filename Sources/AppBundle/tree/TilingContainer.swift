import AppKit
import Common

final class TilingContainer: TreeNode, NonLeafTreeNodeObject { // todo consider renaming to GenericContainer
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    private var _layout: Layout
    var layout: Layout {
        get { _layout }
        set(value) {
            if isDebug && lifeStatus != .alive { die("Can't change layout of not alive TilingContainer") }
            _layout =  value
        }
    }
    var lifeStatus: TilingContainerLifeStatus = .alive // todo tighten its visibility
    private var _scrollingIndex: Int = 0
    var scrollingIndex: Int {
        get { _scrollingIndex }
        set { _scrollingIndex = max(0, newValue) }
    }

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = orientation
        self._layout = layout
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

    var maxScrollingIndex: Int { max(0, inhabitedChildren.count - 2) }

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
                return inhabitedChildren.getOrNil(atIndex: nextIndex)?.findInhabitedLeafWindowRecursive(snappedTo: .left)
            case .right:
                let nextIndex = min(maxScrollingIndex, scrollingIndex + 1)
                scrollingIndex = nextIndex
                return inhabitedChildren.getOrNil(atIndex: nextIndex + 1)?.findInhabitedLeafWindowRecursive(snappedTo: .right)
            case .up, .down:
                return nil
        }
    }

    @MainActor
    private func scrollingPageIndex(for window: Window) -> Int? {
        window.parentsWithSelf.first(where: { $0.parent === self })?.ownIndex(in: .inhabitedOnly)
    }

    @MainActor
    func changeOrientation(_ targetOrientation: Orientation) {
        if orientation == targetOrientation {
            return
        }
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            parentsWithSelf
                .filterIsInstance(of: TilingContainer.self)
                .forEach { $0._orientation.flip() }
        } else {
            _orientation = targetOrientation
        }
    }

    func normalizeOppositeOrientationForNestedContainersRecursive(parentOrientation: Orientation?) {
        switch lifeStatus {
            case .deadOrInvisible: return
            case .alive: _orientation = parentOrientation?.opposite ?? orientation
            case .mustBeFlattened: _orientation = parentOrientation ?? orientation
        }
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainersRecursive(parentOrientation: orientation)
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
