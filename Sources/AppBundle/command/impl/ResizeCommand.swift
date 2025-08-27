import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        if let window = target.windowOrNil, window.isFloating {
            guard let size = try await window.getAxSize(), let topLeftCorner = try await window.getAxTopLeftCorner() else { return false }

            let computeTopLeftCornerAndSize = { (diffSize: CGSize) -> (CGPoint, CGSize) in
                // Calculate current center of the window
                let currentCenter = CGPoint(
                    x: topLeftCorner.x + size.width / 2,
                    y: topLeftCorner.y + size.height / 2
                )
                
                // Calculate new size
                let newSize = CGSize(
                    width: size.width + diffSize.width,
                    height: size.height + diffSize.height
                )
                
                // Calculate new top-left corner to maintain the same center
                let newTopLeftCorner = CGPoint(
                    x: currentCenter.x - newSize.width / 2,
                    y: currentCenter.y - newSize.height / 2
                )
                
                // Ensure the window doesn't go outside the monitor bounds
                let clampedTopLeftCorner = CGPoint(
                    x: max(0, min(newTopLeftCorner.x, target.workspace.workspaceMonitor.width - newSize.width)),
                    y: max(0, min(newTopLeftCorner.y, target.workspace.workspaceMonitor.height - newSize.height))
                )
                
                return (clampedTopLeftCorner, newSize)
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
            window.setAxFrame(newTopLeftCorner, newSize)
            return true
        }

        let candidates = target.windowOrNil?.parentsWithSelf
            .filter { ($0.parent as? TilingContainer)?.layout == .tiles }
            ?? []

        let orientation: Orientation?
        let parent: TilingContainer?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .height:
                orientation = .v
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .smart:
                node = candidates.first
                parent = node?.parent as? TilingContainer
                orientation = parent?.orientation
            case .smartOpposite:
                orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
        }
        guard let parent else { return io.err("resize command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9") }
        guard let orientation else { return false }
        guard let node else { return false }
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
