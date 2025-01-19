import Common

extension CmdArgs {
    func toCommand() -> any Command {
        let command: any Command
        switch Self.info.kind {
            case .balanceSizes:
                command = BalanceSizesCommand(args: self as! BalanceSizesCmdArgs)
            case .close:
                command = CloseCommand(args: self as! CloseCmdArgs)
            case .closeAllWindowsButCurrent:
                command = CloseAllWindowsButCurrentCommand(args: self as! CloseAllWindowsButCurrentCmdArgs)
            case .config:
                command = ConfigCommand(args: self as! ConfigCmdArgs)
            case .debugWindows:
                command = DebugWindowsCommand()
            case .enable:
                command = EnableCommand(args: self as! EnableCmdArgs)
            case .execAndForget:
                error("exec-and-forget is parsed separately")
            case .flattenWorkspaceTree:
                command = FlattenWorkspaceTreeCommand()
            case .focus:
                command = FocusCommand(args: self as! FocusCmdArgs)
            case .focusBackAndForth:
                command = FocusBackAndForthCommand(args: self as! FocusBackAndForthCmdArgs)
            case .focusMonitor:
                command = FocusMonitorCommand(args: self as! FocusMonitorCmdArgs)
            case .fullscreen:
                command = FullscreenCommand(args: self as! FullscreenCmdArgs)
            case .joinWith:
                command = JoinWithCommand(args: self as! JoinWithCmdArgs)
            case .layout:
                command = LayoutCommand(args: self as! LayoutCmdArgs)
            case .listApps:
                command = ListAppsCommand(args: self as! ListAppsCmdArgs)
            case .listExecEnvVars:
                command = ListExecEnvVarsCommand(args: self as! ListExecEnvVarsCmdArgs)
            case .listModes:
                command = ListModesCommand(args: self as! ListModesCmdArgs)
            case .listMonitors:
                command = ListMonitorsCommand(args: self as! ListMonitorsCmdArgs)
            case .listWindows:
                command = ListWindowsCommand(args: self as! ListWindowsCmdArgs)
            case .listWorkspaces:
                command = ListWorkspacesCommand(args: self as! ListWorkspacesCmdArgs)
            case .macosNativeFullscreen:
                command = MacosNativeFullscreenCommand(args: self as! MacosNativeFullscreenCmdArgs)
            case .macosNativeMinimize:
                command = MacosNativeMinimizeCommand(args: self as! MacosNativeMinimizeCmdArgs)
            case .mode:
                command = ModeCommand(args: self as! ModeCmdArgs)
            case .move:
                command = MoveCommand(args: self as! MoveCmdArgs)
            case .moveMouse:
                command = MoveMouseCommand(args: self as! MoveMouseCmdArgs)
            case .moveNodeToMonitor:
                command = MoveNodeToMonitorCommand(args: self as! MoveNodeToMonitorCmdArgs)
            case .moveNodeToWorkspace:
                command = MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
            case .moveWorkspaceToMonitor:
                command = MoveWorkspaceToMonitorCommand(args: self as! MoveWorkspaceToMonitorCmdArgs)
            case .reloadConfig:
                command = ReloadConfigCommand(args: self as! ReloadConfigCmdArgs)
            case .resize:
                command = ResizeCommand(args: self as! ResizeCmdArgs)
            case .split:
                command = SplitCommand(args: self as! SplitCmdArgs)
            case .summonWorkspace:
                command = SummonWorkspaceCommand(args: self as! SummonWorkspaceCmdArgs)
            case .serverVersionInternalCommand:
                command = ServerVersionInternalCommandCommand()
            case .triggerBinding:
                command = TriggerBindingCommand(args: self as! TriggerBindingCmdArgs)
            case .volume:
                command = VolumeCommand(args: self as! VolumeCmdArgs)
            case .workspace:
                command = WorkspaceCommand(args: self as! WorkspaceCmdArgs)
            case .workspaceBackAndForth:
                command = WorkspaceBackAndForthCommand()
        }
        check(command.info == Self.info)
        return command
    }
}
