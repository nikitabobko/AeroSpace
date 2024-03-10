import Common
import TOMLKit

func parseCommand(_ raw: String) -> ParsedCmd<any Command> {
    if raw.starts(with: "exec-and-forget") {
        return .cmd(ExecAndForgetCommand(args: ExecAndForgetCmdArgs(bashScript: raw.removePrefix("exec-and-forget"))))
    }
    switch raw.splitArgs() {
    case .success(let args):
        return parseCommand(args)
    case .failure(let fail):
        return .failure(fail)
    }
}

func parseCommand(_ args: [String]) -> ParsedCmd<any Command> {
    parseCmdArgs(args).map { $0.toCommand() }
}

extension CmdArgs {
    func toCommand() -> any Command {
        let command: any Command
        switch Self.info.kind {
        case .close:
            command = CloseCommand(args: self as! CloseCmdArgs)
        case .closeAllWindowsButCurrent:
            command = CloseAllWindowsButCurrentCommand(args: self as! CloseAllWindowsButCurrentCmdArgs)
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
        case .moveNodeToWorkspace:
            command = MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
        case .move:
            command = MoveCommand(args: self as! MoveCmdArgs)
        case .moveWorkspaceToMonitor:
            command = MoveWorkspaceToMonitorCommand(args: self as! MoveWorkspaceToMonitorCmdArgs)
        case .reloadConfig:
            command = ReloadConfigCommand()
        case .resize:
            command = ResizeCommand(args: self as! ResizeCmdArgs)
        case .split:
            command = SplitCommand(args: self as! SplitCmdArgs)
        case .serverVersionInternalCommand:
            command = ServerVersionInternalCommandCommand()
        case .workspace:
            command = WorkspaceCommand(args: self as! WorkspaceCmdArgs)
        case .workspaceBackAndForth:
            command = WorkspaceBackAndForthCommand()
        }
        check(command.info == Self.info)
        return command
    }
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType) -> String {
    "Expected type is '\(expected)'. But actual type is '\(actual)'"
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType) -> String {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual)
    } else {
        return "Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}
