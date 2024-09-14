public enum CmdKind: String, CaseIterable, Equatable {
    // Sorted

    case balanceSizes = "balance-sizes"
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case config
    case debugWindows = "debug-windows"
    case enable
    case execAndForget = "exec-and-forget"
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case focusBackAndForth = "focus-back-and-forth"
    case focusMonitor = "focus-monitor"
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
    case moveMouse = "move-mouse"
    case moveNodeToMonitor = "move-node-to-monitor"
    case moveNodeToWorkspace = "move-node-to-workspace"
    case moveWorkspaceToMonitor = "move-workspace-to-monitor"
    case reloadConfig = "reload-config"
    case resize
    case split
    case triggerBinding = "trigger-binding"
    case workspace
    case workspaceBackAndForth = "workspace-back-and-forth"

    case serverVersionInternalCommand = "server-version-internal-command"
}

func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .balanceSizes:
                result[kind.rawValue] = defaultSubCommandParser(BalanceSizesCmdArgs.init)
            case .close:
                result[kind.rawValue] = defaultSubCommandParser(CloseCmdArgs.init)
            case .closeAllWindowsButCurrent:
                result[kind.rawValue] = defaultSubCommandParser(CloseAllWindowsButCurrentCmdArgs.init)
            case .config:
                result[kind.rawValue] = SubCommandParser(parseConfigCmdArgs)
            case .debugWindows:
                result[kind.rawValue] = defaultSubCommandParser(DebugWindowsCmdArgs.init)
            case .enable:
                result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case .flattenWorkspaceTree:
                result[kind.rawValue] = defaultSubCommandParser(FlattenWorkspaceTreeCmdArgs.init)
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusBackAndForth:
                result[kind.rawValue] = defaultSubCommandParser(FocusBackAndForthCmdArgs.init)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = SubCommandParser(parseFullscreenCmdArgs)
            case .joinWith:
                result[kind.rawValue] = defaultSubCommandParser(JoinWithCmdArgs.init)
            case .layout:
                result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
            case .listApps:
                result[kind.rawValue] = defaultSubCommandParser(ListAppsCmdArgs.init)
            case .listExecEnvVars:
                result[kind.rawValue] = defaultSubCommandParser(ListExecEnvVarsCmdArgs.init)
            case .listMonitors:
                result[kind.rawValue] = defaultSubCommandParser(ListMonitorsCmdArgs.init)
            case .listWindows:
                result[kind.rawValue] = SubCommandParser(parseRawListWindowsCmdArgs)
            case .listWorkspaces:
                result[kind.rawValue] = SubCommandParser(parseListWorkspacesCmdArgs)
            case .macosNativeFullscreen:
                result[kind.rawValue] = SubCommandParser(parseMacosNativeFullscreenCmdArgs)
            case .macosNativeMinimize:
                result[kind.rawValue] = defaultSubCommandParser(MacosNativeMinimizeCmdArgs.init)
            case .mode:
                result[kind.rawValue] = defaultSubCommandParser(ModeCmdArgs.init)
            case .move:
                result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
                // deprecated
                result["move-through"] = SubCommandParser(parseMoveCmdArgs)
            case .moveMouse:
                result[kind.rawValue] = SubCommandParser(parseMoveMouseCmdArgs)
            case .moveNodeToMonitor:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToMonitorCmdArgs)
            case .moveNodeToWorkspace:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
            case .moveWorkspaceToMonitor:
                result[kind.rawValue] = defaultSubCommandParser(MoveWorkspaceToMonitorCmdArgs.init)
                // deprecated
                result["move-workspace-to-display"] = defaultSubCommandParser(MoveWorkspaceToMonitorCmdArgs.init)
            case .reloadConfig:
                result[kind.rawValue] = defaultSubCommandParser(ReloadConfigCmdArgs.init)
            case .resize:
                result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
            case .split:
                result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
            case .serverVersionInternalCommand:
                if isServer {
                    result[kind.rawValue] = defaultSubCommandParser(ServerVersionInternalCommandCmdArgs.init)
                }
            case .triggerBinding:
                result[kind.rawValue] = SubCommandParser(parseTriggerBindingCmdArgs)
            case .workspace:
                result[kind.rawValue] = SubCommandParser(parseWorkspaceCmdArgs)
            case .workspaceBackAndForth:
                result[kind.rawValue] = defaultSubCommandParser(WorkspaceBackAndForthCmdArgs.init)
        }
    }
    return result
}
