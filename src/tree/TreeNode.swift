import Foundation

class TreeNode: Equatable {
    private var _children: [TreeNode] = []
    var children: [TreeNode] { _children }
    fileprivate weak var _parent: TreeNode? = nil
    var parent: TreeNode? { _parent }
    private var adaptiveWeight: CGFloat

    init(parent: TreeNode, adaptiveWeight: CGFloat) {
        self.adaptiveWeight = adaptiveWeight
        bindTo(parent: parent, adaptiveWeight: adaptiveWeight)
    }

    fileprivate init() {
        adaptiveWeight = 0
    }

    /// See: ``getWeight(_:)``
    func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        if let tilingParent = parent as? TilingContainer {
            if tilingParent.orientation == targetOrientation {
                adaptiveWeight = newValue
            } else {
                error("You can't change \(targetOrientation) weight of nodes located in \(tilingParent.orientation) container")
            }
        } else {
            error("You can't change weight for floating windows and workspace root containers")
        }
    }

    /// Weight itself doesn't make sense. The parent container controls semantics of weight
    func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        if let tilingParent = parent as? TilingContainer {
            return tilingParent.orientation == targetOrientation ? adaptiveWeight : tilingParent.getWeight(targetOrientation)
        } else if let parent = parent as? Workspace {
            if self is MacWindow { // self is a floating window
                error("Weight doesn't make sense for floating windows")
            } else { // root tiling container
                precondition(self is TilingContainer)
                return parent.getWeight(targetOrientation)
            }
        } else {
            error("Not possible")
        }
    }

    @discardableResult
    func bindTo(parent newParent: TreeNode, adaptiveWeight: CGFloat, index: Int = -1) -> PreviousBindingData? {
        if newParent is MacWindow {
            error("Windows can't have children")
        }
        if _parent === newParent {
            error("Binding to the same parent doesn't make sense")
        }
        let result = unbindIfPossible()

        if newParent === NilTreeNode.instance {
            return result
        }
        if let window = self as? MacWindow {
            let newParentWorkspace = newParent.workspace
            newParentWorkspace.mruWindows.pushOrRaise(window)
            newParentWorkspace.assignedMonitor = window.getCenter()?.monitorApproximation
            // Update currentEmptyWorkspace since it's no longer effectively empty
            if newParentWorkspace == currentEmptyWorkspace {
                currentEmptyWorkspace = getOrCreateNextEmptyWorkspace()
            }
        }
        newParent._children.insert(self, at: index == -1 ? newParent._children.count : index)
        _parent = newParent
        return result
    }

    private func unbindIfPossible() -> PreviousBindingData? {
        guard let _parent else { return nil }
        let workspace = workspace
        if let window = self as? MacWindow {
            workspace.mruWindows.remove(window)
        }

        let index = _parent._children.remove(element: self) ?? errorT("Can't find child in its parent")
        self._parent = nil

        if workspace.isEffectivelyEmpty { // It became empty
            currentEmptyWorkspace = workspace
            currentEmptyWorkspace.assignedMonitor = nil
        }
        return PreviousBindingData(adaptiveWeight: adaptiveWeight, index: index)
    }

    @discardableResult
    func unbindFromParent() -> PreviousBindingData {
        unbindIfPossible() ?? errorT("\(self) is already unbinded")
    }

    static func ==(lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs === rhs
    }
}

struct PreviousBindingData {
    let adaptiveWeight: CGFloat
    let index: Int
}

class NilTreeNode: TreeNode {
    private override init() {
        super.init()
    }
    static let instance = NilTreeNode()
}
