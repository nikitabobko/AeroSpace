enum Orientation {
    case H
    case V
}

protocol TilingContainer: TreeNode {
    var orientation: Orientation { get }
}

class HListContainer: TilingContainer {
    var orientation: Orientation { .H }
    var children: WeakArray<TreeNodeClass> = WeakArray()
    var parent: TreeNode

    init(_ parent: TreeNode) {
        self.parent = parent
    }
}

class VListContainer: TilingContainer {
    var orientation: Orientation { .V }
    var children: WeakArray<TreeNodeClass> = WeakArray()
    var parent: TreeNode

    init(_ parent: TreeNode) {
        self.parent = parent
    }
}

class HAccordionContainer: TilingContainer {
    var orientation: Orientation { .H }
    var children: WeakArray<TreeNodeClass> = WeakArray()
    var parent: TreeNode

    init(_ parent: TreeNode) {
        self.parent = parent
    }
}

class VAccordionContainer: TilingContainer {
    var orientation: Orientation { .V }
    var children: WeakArray<TreeNodeClass> = WeakArray()
    var parent: TreeNode

    init(_ parent: TreeNode) {
        self.parent = parent
    }
}

class FloatingChildrenContainer: TreeNode {
    var children: WeakArray<TreeNodeClass> = WeakArray()
    var parent: TreeNode

    init(_ parent: TreeNode) {
        self.parent = parent
    }
}