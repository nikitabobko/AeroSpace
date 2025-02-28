import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        if let window = target.windowOrNil, window.isFloating {
            guard let size = window.getSize(), let topLeftCorner = window.getTopLeftCorner() else { return false }

            let computeTopLeftCorner = { (newSize: CGSize) -> CGPoint in
                let newX = if topLeftCorner.x + newSize.width > target.workspace.workspaceMonitor.width {
                    max(0, topLeftCorner.x - (topLeftCorner.x + newSize.width - target.workspace.workspaceMonitor.width))
                } else {
                    topLeftCorner.x
                }

                let newY = if topLeftCorner.y + newSize.height > target.workspace.workspaceMonitor.height {
                    max(0, topLeftCorner.y - (topLeftCorner.y + newSize.height - target.workspace.workspaceMonitor.height))
                } else {
                    topLeftCorner.y
                }

                return CGPoint(x: newX, y: newY)
            }

            let newTopLeftCorner: CGPoint
            let newSize: CGSize
            let isWidthDominant = size.width >= size.height

            switch args.dimension.val {
                case .width:
                    let diff: CGFloat = switch args.units.val {
                        case .set(let unit): CGFloat(unit) - size.width
                        case .add(let unit): CGFloat(unit)
                        case .subtract(let unit): -CGFloat(unit)
                    }
                    let width = size.width + diff
                    newSize = CGSize(width: width, height: size.height)
                    newTopLeftCorner = computeTopLeftCorner(newSize)

                case .height:
                    let diff: CGFloat = switch args.units.val {
                        case .set(let unit): CGFloat(unit) - size.height
                        case .add(let unit): CGFloat(unit)
                        case .subtract(let unit): -CGFloat(unit)
                    }
                    let height = size.height + diff
                    newSize = CGSize(width: size.width, height: height)
                    newTopLeftCorner = computeTopLeftCorner(newSize)

                case .smart:
                    let diff: CGFloat = switch args.units.val {
                        case .set(let unit): CGFloat(unit) - (isWidthDominant ? size.width : size.height)
                        case .add(let unit): CGFloat(unit)
                        case .subtract(let unit): -CGFloat(unit)
                    }
                    newSize = if isWidthDominant {
                        CGSize(width: size.width + diff, height: size.height + diff * (size.height / size.width))
                    } else {
                        CGSize(width: size.width + diff * (size.width / size.height), height: size.height + diff)
                    }
                    newTopLeftCorner = computeTopLeftCorner(newSize)

                case .smartOpposite:
                    let diff: CGFloat = switch args.units.val {
                        case .set(let unit): CGFloat(unit) - (isWidthDominant ? size.height : size.width)
                        case .add(let unit): CGFloat(unit)
                        case .subtract(let unit): -CGFloat(unit)
                    }
                    newSize = if isWidthDominant {
                        CGSize(width: size.width + diff * (size.width / size.height), height: size.height + diff)
                    } else {
                        CGSize(width: size.width + diff, height: size.height + diff * (size.height / size.width))
                    }
                    newTopLeftCorner = computeTopLeftCorner(newSize)
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
