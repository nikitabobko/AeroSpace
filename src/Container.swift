enum Orientation {
    case H
    case V
}

protocol Container: TreeNode {
    var orientation: Orientation { get }
}

class HStackContainer: Container {
    var orientation: Orientation { .H }
    var children: [TreeNode] = []
}

class VStackContainer: Container {
    var orientation: Orientation { .V }
    var children: [TreeNode] = []
}

class HAccordionContainer: Container {
    var orientation: Orientation { .H }
    var children: [TreeNode] = []
}

class VAccordionContainer: Container {
    var orientation: Orientation { .V }
    var children: [TreeNode] = []
}
