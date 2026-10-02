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
