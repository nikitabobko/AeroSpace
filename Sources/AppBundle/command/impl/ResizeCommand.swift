import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }

        let candidates = focus.windowOrNil?.parentsWithSelf
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
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - node.getWeight(orientation)
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }

        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return true
    }
}
