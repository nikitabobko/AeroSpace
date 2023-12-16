import TOMLKit

typealias Parsed<T> = Result<T, String>
extension String: Error {}

func parseQueryCommand(_ raw: String) -> Parsed<QueryCommand> {
    if raw.contains("'") || raw.contains("\"") {
        return .failure("Quotation marks are reserved for future use")
    } else if raw == "version" || raw == "--version" || raw == "-v" {
        return .success(VersionCommand())
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
        case .execAndWait:
            command = ExecAndWaitCommand(args: self as! ExecAndWaitCmdArgs)
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
        case .mode:
            command = ModeCommand(args: self as! ModeCmdArgs)
        case .moveNodeToWorkspace:
            command = MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
        case .moveThrough:
            command = MoveThroughCommand(args: self as! MoveThroughCmdArgs)
        case .moveWorkspaceToMonitor:
            command = MoveWorkspaceToMonitorCommand(args: self as! MoveWorkspaceToMonitorCmdArgs)
        case .reloadConfig:
            command = ReloadConfigCommand()
        case .resize:
            command = ResizeCommand(args: self as! ResizeCmdArgs)
        case .split:
            command = SplitCommand(args: self as! SplitCmdArgs)
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
