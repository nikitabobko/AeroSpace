enum Orientation {
    case H
    case V
}

protocol TilingContainer: TreeNode {
    var orientation: Orientation { get }
}

class HListContainer: TreeNode, TilingContainer {
    var orientation: Orientation { .H }

    override init(parent: TreeNode) {
        super.init(parent: parent)
    }
}

class VListContainer: TreeNode, TilingContainer {
    var orientation: Orientation { .V }

    override init(parent: TreeNode) {
        super.init(parent: parent)
    }
}

class HAccordionContainer: TreeNode, TilingContainer {
    var orientation: Orientation { .H }

    override init(parent: TreeNode) {
        super.init(parent: parent)
    }
}

class VAccordionContainer: TreeNode, TilingContainer {
    var orientation: Orientation { .V }

    override init(parent: TreeNode) {
        super.init(parent: parent)
    }
}

//class FloatingChildrenContainer: TreeNode {
//    var children: WeakArray<TreeNodeClass> = WeakArray()
//    var parent: TreeNode
//
//    init(_ parent: TreeNode) {
//        self.parent = parent
//    }
//}