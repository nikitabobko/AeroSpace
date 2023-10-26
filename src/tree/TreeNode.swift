class TreeNode: Equatable {
    private var _children: [TreeNode] = []
    var children: [TreeNode] { _children }
    fileprivate weak var _parent: NonLeafTreeNode? = nil
    var parent: NonLeafTreeNode? { _parent }
    private var adaptiveWeight: CGFloat
    private let _mruChildren: MruStack<TreeNode> = MruStack()
    var mostRecentChildren: some Sequence<TreeNode> { _mruChildren }
    /// Helps to avoid flickering when cycling children of accordion container with focus command
    var mostRecentChildIndexForAccordion: Int? = nil
    var lastAppliedLayoutRect: Rect? = nil

    init(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) {
        self.adaptiveWeight = adaptiveWeight
        bindTo(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    fileprivate init() {
        adaptiveWeight = 0
    }

    /// See: ``getWeight(_:)``
    func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        switch parent?.kind {
        case .tilingContainer(let parent):
            if parent.orientation == targetOrientation {
                adaptiveWeight = newValue
            } else {
                error("You can't change \(targetOrientation) weight of nodes located in \(parent.orientation) container")
            }
        case .workspace:
            error("Can't change weight for floating windows and workspace root containers")
        case nil:
            error("Can't change weight if TreeNode doesn't have parent")
        }
    }

    /// Weight itself doesn't make sense. The parent container controls semantics of weight
    func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        switch parent?.kind {
        case .tilingContainer(let parent):
            return parent.orientation == targetOrientation ? adaptiveWeight : parent.getWeight(targetOrientation)
        case .workspace(let parent):
            switch genericKind {
            case .window: // self is a floating window
                error("Weight doesn't make sense for floating windows")
            case .tilingContainer: // root tiling container
                return parent.getWeight(targetOrientation)
            case .workspace:
                error("Workspaces can't be child")
            }
        case nil:
            error("Weight doesn't make sense for containers without parent")
        }
    }

    @discardableResult
    func bindTo(parent newParent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int = INDEX_BIND_LAST) -> BindingData? { // todo make index parameter mandatory
        if _parent === newParent {
            error("Binding to the same parent doesn't make sense")
        }
        if newParent is Window {
            windowsCantHaveChildren()
        }
        let result = unbindIfPossible()

        if newParent === NilTreeNode.instance {
            return result
        }
        if adaptiveWeight == WEIGHT_AUTO {
            switch newParent.kind {
            case .tilingContainer(let newParent):
                self.adaptiveWeight = newParent.children.sumOf { $0.getWeight(newParent.orientation) }
                    .div(newParent.children.count)
                    ?? 1
            case .workspace:
                switch genericKind {
                case .window:
                    self.adaptiveWeight = WEIGHT_FLOATING
                case .tilingContainer:
                    self.adaptiveWeight = 1
                case .workspace:
                    error("Binding workspace to workspace is illegal")
                }
            }
        } else {
            self.adaptiveWeight = adaptiveWeight
        }
        newParent._children.insert(self, at: index != INDEX_BIND_LAST ? index : newParent._children.count)
        _parent = newParent
        markAsMostRecentChild()
        return result
    }

    private func unbindIfPossible() -> BindingData? {
        guard let _parent else { return nil }

        let index = _parent._children.remove(element: self) ?? errorT("Can't find child in its parent")
        check(_parent._mruChildren.remove(self))
        self._parent = nil

        return BindingData(parent: _parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    func markAsMostRecentChild() {
        guard let _parent else { return }
        _parent._mruChildren.pushOrRaise(self)
        _parent.markAsMostRecentChild()
    }

    func markAsMostRecentChildForAccordion() {
        guard let _parent else { return }
        _parent.mostRecentChildIndexForAccordion = ownIndexOrNil!
        _parent.markAsMostRecentChildForAccordion()
    }

    @discardableResult
    func unbindFromParent() -> BindingData {
        unbindIfPossible() ?? errorT("\(self) is already unbinded")
    }

    static func ==(lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs === rhs
    }

    private var userData: [String:Any] = [:]
    func getUserData<T>(key: TreeNodeUserDataKey<T>) -> T? { userData[key.key] as! T? }
    func putUserData<T>(key: TreeNodeUserDataKey<T>, data: T) {
        userData[key.key] = data
    }
    @discardableResult
    func cleanUserData<T>(key: TreeNodeUserDataKey<T>) -> T? { userData.removeValue(forKey: key.key) as! T? }

    @discardableResult
    func focus() -> Bool { error("Not implemented") }
    func getRect() -> Rect? { error("Not implemented") }
}

struct TreeNodeUserDataKey<T> {
    let key: String
}

private let WEIGHT_FLOATING = CGFloat(-2)
/// Splits containers evenly if tiling.
///
/// Reset weight is bind to workspace (aka "floating windows")
let WEIGHT_AUTO = CGFloat(-1)

let INDEX_BIND_LAST = -1

struct BindingData {
    let parent: NonLeafTreeNode
    let adaptiveWeight: CGFloat
    let index: Int
}

class NilTreeNode: TreeNode, NonLeafTreeNode {
    private override init() {
        super.init()
    }
    static let instance = NilTreeNode()
}
