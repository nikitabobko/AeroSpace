import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        if let window = target.windowOrNil, window.isFloating {
            guard let size = window.getSize(), let topLeftCorner = window.getTopLeftCorner() else { return false }

            let computeTopLeftCornerAndSize = { (diffSize: CGSize) -> (CGPoint, CGSize) in
                let newX = if topLeftCorner.x + size.width + diffSize.width / 2 > target.workspace.workspaceMonitor.width {
                    max(0, target.workspace.workspaceMonitor.width - size.width - diffSize.width)
                } else {
                    max(0, topLeftCorner.x - diffSize.width / 2)
                }

                let newY = if topLeftCorner.y + size.height + diffSize.height / 2 > target.workspace.workspaceMonitor.height {
                    max(0, target.workspace.workspaceMonitor.height - size.height - diffSize.height)
                } else {
                    topLeftCorner.y - diffSize.height / 2
                }

                return (CGPoint(x: newX, y: newY), CGSize(width: size.width + diffSize.width, height: size.height + diffSize.height))
            }

            let isWidthDominant = size.width >= size.height
            let diff: CGFloat = switch (args.units.val, args.dimension.val) {
                case (.set(let unit), .width): CGFloat(unit) - size.width
                case (.set(let unit), .height): CGFloat(unit) - size.height
                case (.set(let unit), .smart): CGFloat(unit) - (isWidthDominant ? size.width : size.height)
                case (.set(let unit), .smartOpposite): CGFloat(unit) - (isWidthDominant ? size.height : size.width)
                case (.add(let unit), _): CGFloat(unit)
                case (.subtract(let unit), _): -CGFloat(unit)
            }

            let newTopLeftCorner: CGPoint
            let newSize: CGSize
            switch args.dimension.val {
                case .width:
                    (newTopLeftCorner, newSize) = computeTopLeftCornerAndSize(CGSize(width: diff, height: 0))
                case .height:
                    (newTopLeftCorner, newSize) = computeTopLeftCornerAndSize(CGSize(width: 0, height: diff))
                case .smart:
                    let diffSize = if isWidthDominant {
                        CGSize(width: diff, height: diff * (size.height / size.width))
                    } else {
                        CGSize(width: diff * (size.width / size.height), height: diff)
                    }
                    (newTopLeftCorner, newSize) = computeTopLeftCornerAndSize(diffSize)
                case .smartOpposite:
                    let diffSize = if isWidthDominant {
                        CGSize(width: diff * (size.width / size.height), height: diff)
                    } else {
                        CGSize(width: diff, height: diff * (size.height / size.width))
                    }
                    (newTopLeftCorner, newSize) = computeTopLeftCornerAndSize(diffSize)
            }
            return window.setFrame(newTopLeftCorner, newSize)
        }

        let candidates = target.windowOrNil?.parentsWithSelf
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
            case .smartOpposite:
                guard let _orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite else { return false }
                orientation = _orientation
                guard let first = candidates.first(where: { ($0.parent as! TilingContainer).orientation == orientation }) else { return false }
                node = first
                parent = first.parent as! TilingContainer
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
