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

class FloatingChildrenContainer: TreeNode {
    //convenience init(_ parent: TreeNode) {
    //    self.init(parent)
    //}
}