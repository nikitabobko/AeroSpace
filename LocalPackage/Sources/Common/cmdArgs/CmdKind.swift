public enum CmdKind: String, CaseIterable, Equatable {
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case enable
    case execAndForget = "exec-and-forget"
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case fullscreen
    case joinWith = "join-with"
    case layout
    case listApps = "list-apps"
    case mode
    case move = "move"
    case moveNodeToWorkspace = "move-node-to-workspace"
    case moveWorkspaceToMonitor = "move-workspace-to-monitor"
    case reloadConfig = "reload-config"
    case resize
    case split
    case version
    case workspace
    case workspaceBackAndForth = "workspace-back-and-forth"
}
