import Common

struct ResizeCommand: Command { // todo cover with tests
    let info: CmdStaticInfo = ResizeCmdArgs.info
    let args: ResizeCmdArgs

    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool { // todo support key repeat
        check(Thread.current.isMainThread)

        let candidates = subject.windowOrNil?.parentsWithSelf
            .filter { ($0.parent as? TilingContainer)?.layout == .tiles }
            ?? []

        let orientation: Orientation
        let parent: TilingContainer
        let node: TreeNode
        switch args.dimension.val {
        case .width:
            orientation = .h
            guard let first = candidates.first(where: { ($0.parent as! TilingContainer).orientation == orientation }) else { return false }
            node = first
            parent = first.parent as! TilingContainer
        case .height:
            orientation = .v
            guard let first = candidates.first(where: { ($0.parent as! TilingContainer).orientation == orientation }) else { return false }
            node = first
            parent = first.parent as! TilingContainer
        case .smart:
            guard let first = candidates.first else { return false }
            node = first
            parent = first.parent as! TilingContainer
            orientation = parent.orientation
        }
        let diff: CGFloat
        switch args.units.val {
        case .set(let unit):
            diff = CGFloat(unit) - node.getWeight(orientation)
        case .add(let unit):
            diff = CGFloat(unit)
        case .subtract(let unit):
            diff = -CGFloat(unit)
        }

        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return true
    }
}
