import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if args.root {
            guard let targetWorkspace = resolveTargetWorkspace(.success(target.workspace), target, io) else { return .fail }
            return moveRootTilingContainerToWorkspace(target, targetWorkspace, io, focusFollowsWindow: args.focusFollowsWindow, failIfNoop: args.failIfNoop)
        }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let subjectWs = window.nodeWorkspace.toResult("Window \(window.windowId) doesn't belong to any workspace")
        guard let targetWorkspace = resolveTargetWorkspace(subjectWs, target, io) else { return .fail }
        return moveWindowToWorkspace(window, targetWorkspace, io, focusFollowsWindow: args.focusFollowsWindow, failIfNoop: args.failIfNoop)
    }

    @MainActor
    private func resolveTargetWorkspace(_ subjectWs: ResOrStr<Workspace>, _ target: LiveFocus, _ io: CmdIo) -> Workspace? {
        switch args.target.val {
            case .relative(let nextPrev):
                guard let subjectWs = subjectWs.getOrNil(appendErrorTo: &io.stderr) else { return nil }
                let ws = getNextPrevWorkspace(
                    current: subjectWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                return ws.getOrNil(appendErrorTo: &io.stderr)
            case .direct(let name):
                return Workspace.get(byName: name.raw)
        }
    }
}

@MainActor
func moveWindowToWorkspace(_ window: Window, _ targetWorkspace: Workspace, _ io: CmdIo, focusFollowsWindow: Bool, failIfNoop: Bool, index: Int = INDEX_BIND_LAST) -> BinaryExitCode {
    if window.nodeWorkspace == targetWorkspace {
        return switch failIfNoop {
            case true: .fail
            case false:
                .succ(io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code"))
        }
    }
    let targetContainer: NonLeafTreeNodeObject = window.isFloating
        ? targetWorkspace.floatingWindowsContainer
        : targetWorkspace.rootTilingContainer
    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
    return .from(bool: focusFollowsWindow ? window.focusWindow() : true)
}

/// The root tiling container is moved the same way as a tiling window: it's appended to the root tiling container of
/// the target workspace. If the target workspace doesn't have tiling windows, the moved container becomes the new root
/// after the normalization (enable-normalization-flatten-containers), which preserves its layout
@MainActor
private func moveRootTilingContainerToWorkspace(_ target: LiveFocus, _ targetWorkspace: Workspace, _ io: CmdIo, focusFollowsWindow: Bool, failIfNoop: Bool) -> BinaryExitCode {
    let subjectWs = target.workspace
    if subjectWs == targetWorkspace {
        return switch failIfNoop {
            case true: .fail
            case false:
                .succ(io.err("Tiling root node already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code"))
        }
    }
    let root = subjectWs.rootTilingContainer
    guard let mruWindow = root.mostRecentWindowRecursive ?? root.anyLeafWindowRecursive else {
        return switch failIfNoop {
            case true: .fail
            case false:
                .succ(io.err("Workspace '\(subjectWs.name)' doesn't have tiling windows. Tip: use --fail-if-noop to exit with non-zero code"))
        }
    }
    // Prefer the subject window if it's moved together with the root
    let windowToFocus = target.windowOrNil?.takeIf { $0.parentsWithSelf.contains(root) } ?? mruWindow
    root.bind(to: targetWorkspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return .from(bool: focusFollowsWindow ? windowToFocus.focusWindow() : true)
}
