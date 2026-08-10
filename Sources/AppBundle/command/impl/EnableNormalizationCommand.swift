import Common

struct EnableNormalizationCommand: Command {
    let args: EnableNormalizationCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let workspace = target.workspace
        let kind = args.kind.val
        // An override lives only as long as its workspace. Refuse to install one on a
        // workspace that garbageCollectUnusedWorkspaces is about to destroy, instead of
        // succeeding with no lasting effect.
        if args.targetState.val != .reset && workspace.isDoomedToGarbageCollection {
            return .fail(io.err("Workspace '\(workspace.name)' is empty and invisible, so it would be garbage-collected together with the override. Focus the workspace first, or add it to 'persistent-workspaces'"))
        }
        switch args.targetState.val {
            case .on, .off:
                let newValue = args.targetState.val == .on
                if workspace.normalizationOverride[kind] == newValue {
                    if args.failIfNoop { return .fail }
                    let state = newValue ? "enabled" : "disabled"
                    return .succ(io.err("Normalization '\(kind.rawValue)' is already \(state) on workspace '\(workspace.name)'. Tip: use --fail-if-noop to exit with non-zero code"))
                }
                workspace.normalizationOverride[kind] = newValue
            case .toggle:
                workspace.normalizationOverride[kind] = !workspace.isNormalizationEnabled(kind)
            case .reset:
                workspace.normalizationOverride.removeValue(forKey: kind)
        }
        return .succ
    }
}
