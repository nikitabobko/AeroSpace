enum Orientation {
    case Row
    case Column
}

protocol Container: TreeNode {
    var orientation: Orientation { get }
}

class RowContainer: Container {
    var orientation: Orientation { .Row }
    var children: [TreeNode] = []
}

class ColumnContainer: Container {
    var orientation: Orientation { .Column }
    var children: [TreeNode] = []
}

class MaximizedRowContainer: Container {
    var orientation: Orientation { .Row }
    var children: [TreeNode] = []
}

class MaximizedColumnContainer: Container {
    var orientation: Orientation { .Column }
    var children: [TreeNode] = []
}
