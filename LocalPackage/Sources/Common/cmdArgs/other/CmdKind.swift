public enum CmdKind: String, CaseIterable, Equatable {
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case debugWindows = "debug-windows"
    case enable
    case execAndForget = "exec-and-forget"
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case fullscreen
    case joinWith = "join-with"
    case layout
    case listApps = "list-apps"
    case listExecEnvVars = "list-exec-env-vars"
    case listMonitors = "list-monitors"
    case listWindows = "list-windows"
    case listWorkspaces = "list-workspaces"
    case macosNativeFullscreen = "macos-native-fullscreen"
    case macosNativeMinimize = "macos-native-minimize"
    case mode
    case move = "move"
    case moveNodeToWorkspace = "move-node-to-workspace"
    case moveWorkspaceToMonitor = "move-workspace-to-monitor"
    case reloadConfig = "reload-config"
    case resize
    case split
    case workspace
    case workspaceBackAndForth = "workspace-back-and-forth"

    case serverVersionInternalCommand = "server-version-internal-command"
}
