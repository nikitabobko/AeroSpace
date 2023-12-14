import TOMLKit

typealias Parsed<T> = Result<T, String>
extension String: Error {}

func parseQueryCommand(_ raw: String) -> Parsed<QueryCommand> {
    if raw.contains("'") || raw.contains("\"") {
        return .failure("Quotation marks are reserved for future use")
    } else if raw == "version" || raw == "--version" || raw == "-v" {
        return .success(VersionCommand())
    } else if raw == "list-apps" {
        return .success(ListAppsCommand())
    } else if raw == "" {
        return .failure("Can't parse empty string query command")
    } else {
        return .failure("Unrecognized query command '\(raw)'")
    }
}

func parseCommand(_ raw: String) -> ParsedCmd<Command> {
    parseCmdArgs(raw).map { $0.toCommand() }
}

extension CmdArgs {
    func toCommand() -> Command {
        switch self.kind {
        case .close:
            return CloseCommand()
        case .closeAllWindowsButCurrent:
            return CloseAllWindowsButCurrentCommand()
        case .enable:
            return EnableCommand(args: self as! EnableCmdArgs)
        case .execAndForget:
            return ExecAndForgetCommand(args: self as! ExecAndForgetCmdArgs)
        case .execAndWait:
            return ExecAndWaitCommand(args: self as! ExecAndWaitCmdArgs)
        case .flattenWorkspaceTree:
            return FlattenWorkspaceTreeCommand()
        case .focus:
            return FocusCommand(args: self as! FocusCmdArgs)
        case .fullscreen:
            return FullscreenCommand()
        case .joinWith:
            return JoinWithCommand(args: self as! JoinWithCmdArgs)
        case .layout:
            return LayoutCommand(args: self as! LayoutCmdArgs)
        case .mode:
            return ModeCommand(args: self as! ModeCmdArgs)
        case .moveNodeToWorkspace:
            return MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
        case .moveThrough:
            return MoveThroughCommand(args: self as! MoveThroughCmdArgs)
        case .moveWorkspaceToMonitor:
            return MoveWorkspaceToMonitorCommand(args: self as! MoveWorkspaceToMonitorCmdArgs)
        case .reloadConfig:
            return ReloadConfigCommand()
        case .resize:
            return ResizeCommand(args: self as! ResizeCmdArgs)
        case .split:
            return SplitCommand(args: self as! SplitCmdArgs)
        case .workspace:
            return WorkspaceCommand(args: self as! WorkspaceCmdArgs)
        case .workspaceBackAndForth:
            return WorkspaceBackAndForthCommand()
        }
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
