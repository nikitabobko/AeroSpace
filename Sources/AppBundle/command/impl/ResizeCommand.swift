import AppKit
import Common

struct ResizeCommand: Command {
    let args: ResizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let resizeTarget = resolveResizeTarget(target.windowOrNil, args.dimension.val) else {
            return .fail(io.err("resize command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9"))
        }
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - resizeTarget.nodeWeight
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }

        return resizeTarget.changeWeight(by: diff) ? .succ : .fail
    }
}

/// The node that `resize`-like commands resize, and the axis they resize it along
struct ResizeTarget {
    let node: TreeNode
    let parent: TilingContainer
    let orientation: Orientation

    @MainActor var nodeWeight: CGFloat { node.getWeight(orientation) }
    @MainActor var parentWeight: CGFloat { CGFloat(parent.children.sumOfDouble { $0.getWeight(orientation) }) }

    /// Changes the weight of ``node`` by `diff`, and compensates the change on its siblings,
    /// so that ``parent`` preserves its size. Returns `false` if ``node`` has no siblings
    @MainActor
    func changeWeight(by diff: CGFloat) -> Bool {
        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return true
    }
}

@MainActor
func resolveResizeTarget(_ window: Window?, _ dimension: ResizeCmdArgs.Dimension) -> ResizeTarget? {
    let candidates = window?.parentsWithSelf
        .filter { ($0.parent as? TilingContainer)?.layout == .tiles }
        ?? []

    let orientation: Orientation?
    let node: TreeNode?
    switch dimension {
        case .width:
            orientation = .h
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
        case .height:
            orientation = .v
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
        case .smart:
            node = candidates.first
            orientation = (node?.parent as? TilingContainer)?.orientation
        case .smartOpposite:
            orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
    }
    guard let orientation, let node, let parent = node.parent as? TilingContainer else { return nil }
    return ResizeTarget(node: node, parent: parent, orientation: orientation)
}
