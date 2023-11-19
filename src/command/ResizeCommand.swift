struct ResizeCommand: Command { // todo cover with tests
    enum Dimension: String {
        case width, height, smart
    }

    enum ResizeMode: String {
        case set, add, subtract
    }

    let dimension: Dimension
    let mode: ResizeMode
    let unit: UInt

    func runWithoutLayout(state: inout FocusState) { // todo support key repeat
        check(Thread.current.isMainThread)

        let candidates = state.window?.parentsWithSelf
            .filter { ($0.parent as? TilingContainer)?.layout == .tiles }
            ?? []

        let orientation: Orientation
        let parent: TilingContainer
        let node: TreeNode
        switch dimension {
        case .width:
            orientation = .h
            guard let first = candidates.first(where: { ($0.parent as! TilingContainer).orientation == orientation }) else { return }
            node = first
            parent = first.parent as! TilingContainer
        case .height:
            orientation = .v
            guard let first = candidates.first(where: { ($0.parent as! TilingContainer).orientation == orientation }) else { return }
            node = first
            parent = first.parent as! TilingContainer
        case .smart:
            guard let first = candidates.first else { return }
            node = first
            parent = first.parent as! TilingContainer
            orientation = parent.orientation
        }
        let diff: CGFloat
        switch mode {
        case .set:
            diff = CGFloat(unit) - node.getWeight(orientation)
        case .add:
            diff = CGFloat(unit)
        case .subtract:
            diff = -CGFloat(unit)
        }

        guard let childDiff = diff.div(parent.children.count - 1) else { return }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
    }
}
