import Common

struct MoveNodeToContainerCommand: Command {
    let args: MoveNodeToContainerCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        switch window.windowParentCases {
            case nil: return .fail(io.err(bugPrompt()))
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return .fail(io.err(moveOutMacosUnconventionalWindow))
            case .macosPopupWindowsContainer:
                return .fail(io.err(bugPrompt())) // Impossible
            case .tilingContainer, .floatingWindowsContainer: break
        }
        let workspace = Workspace.get(byName: args.targetWorkspace.val.raw)
        let path = args.containerPath.val
        guard let container = workspace.rootTilingContainer.resolve(path) else {
            return .fail(io.err("Container \(path.description.singleQuoted) doesn't exist in workspace \(workspace.name.singleQuoted)"))
        }
        // <index> counts the inhabited children, the same way dump-workspace-tree reports them
        var index = args.index.val
        let count = container.inhabitedChildren.count
        if index > count {
            return .fail(io.err("Index \(index) is out of bounds. Container \(path.description.singleQuoted) in workspace \(workspace.name.singleQuoted) has \(count) children"))
        }
        if window.parent === container, let ownIndex = window.ownIndex(in: .inhabitedOnly) {
            // <index> refers to the children list before the move. The window itself is a part of that list
            if ownIndex < index { index -= 1 }
            let prevBinding = window.unbindFromParent()
            window.bind(to: container, adaptiveWeight: prevBinding.adaptiveWeight, index: container.bindIndex(forInhabitedIndex: index))
        } else {
            window.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: container.bindIndex(forInhabitedIndex: index))
        }
        return .from(bool: args.focusFollowsWindow ? window.focusWindow() : true)
    }
}

extension TilingContainer {
    /// Paths count inhabited children only, the same way dump-workspace-tree reports them
    func resolve(_ path: ContainerPath) -> TilingContainer? {
        var container = self
        for index in path.indices {
            guard let child = container.inhabitedChildren.getOrNil(atIndex: index) as? TilingContainer else { return nil }
            container = child
        }
        return container
    }

    /// The position among all children (tombstones included) that puts a new child at `index` among the inhabited ones
    func bindIndex(forInhabitedIndex index: Int) -> Int {
        inhabitedChildren.getOrNil(atIndex: index).flatMap { children.firstIndex(of: $0) } ?? children.count
    }
}
