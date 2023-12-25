import Common
import TOMLKit

func parseCommand(_ raw: String) -> ParsedCmd<Command> {
    parseCmdArgs(raw).map { $0.toCommand() }
}

extension CmdArgs {
    func toCommand() -> Command {
        let command: Command
        switch Self.info.kind {
        case .close:
            command = CloseCommand()
        case .closeAllWindowsButCurrent:
            command = CloseAllWindowsButCurrentCommand()
        case .enable:
            command = EnableCommand(args: self as! EnableCmdArgs)
        case .execAndForget:
            command = ExecAndForgetCommand(args: self as! ExecAndForgetCmdArgs)
        case .flattenWorkspaceTree:
            command = FlattenWorkspaceTreeCommand()
        case .focus:
            command = FocusCommand(args: self as! FocusCmdArgs)
        case .fullscreen:
            command = FullscreenCommand()
        case .joinWith:
            command = JoinWithCommand(args: self as! JoinWithCmdArgs)
        case .layout:
            command = LayoutCommand(args: self as! LayoutCmdArgs)
        case .listApps:
            command = ListAppsCommand()
        case .listMonitors:
            command = ListMonitorsCommand(args: self as! ListMonitorsCmdArgs)
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
        case .version:
            command = VersionCommand()
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
