public func parseCmdArgs(_ args: [String]) -> ParsedCmd<any CmdArgs> {
    let subcommand = String(args.first ?? "")
    if subcommand.isEmpty {
        return .failure("Can't parse empty string command")
    }
    if let subcommandParser: any SubCommandParserProtocol = subcommands[subcommand] {
        return subcommandParser.parse(args: Array(args.dropFirst()))
    } else {
        return .failure("Unrecognized subcommand '\(subcommand)'")
    }
}

private func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .close:
                result[kind.rawValue] = defaultSubCommandParser(CloseCmdArgs.init)
            case .closeAllWindowsButCurrent:
                result[kind.rawValue] = defaultSubCommandParser(CloseAllWindowsButCurrentCmdArgs.init)
            case .config:
                result[kind.rawValue] = SubCommandParser(parseConfigCmdArgs)
            case .debugWindows:
                result[kind.rawValue] = defaultSubCommandParser(DebugWindowsCmdArgs.init)
            case .enable:
                result[kind.rawValue] = defaultSubCommandParser(EnableCmdArgs.init)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case .flattenWorkspaceTree:
                result[kind.rawValue] = defaultSubCommandParser(FlattenWorkspaceTreeCmdArgs.init)
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = defaultSubCommandParser(FullscreenCmdArgs.init)
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
                result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
            case .listWorkspaces:
                result[kind.rawValue] = SubCommandParser(parseListWorkspacesCmdArgs)
            case .macosNativeFullscreen:
                result[kind.rawValue] = defaultSubCommandParser(MacosNativeFullscreenCmdArgs.init)
            case .macosNativeMinimize:
                result[kind.rawValue] = defaultSubCommandParser(MacosNativeMinimizeCmdArgs.init)
            case .mode:
                result[kind.rawValue] = defaultSubCommandParser(ModeCmdArgs.init)
            case .moveNodeToMonitor:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToMonitorCmdArgs)
            case .moveNodeToWorkspace:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
            case .move:
                result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
                // deprecated
                result["move-through"] = SubCommandParser(parseMoveCmdArgs)
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

private func defaultSubCommandParser<T: RawCmdArgs>(_ raw: @escaping (EquatableNoop<[String]>) -> T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw(.init(args)), args) }
}

private func defaultSubCommandParser<T: RawCmdArgs>(_ raw: @escaping ([String]) -> T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw(args), args) }
}

private let subcommands: [String: any SubCommandParserProtocol] = initSubcommands()

private protocol SubCommandParserProtocol<T> {
    associatedtype T where T: CmdArgs
    var _parse: ([String]) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: [String]) -> ParsedCmd<any CmdArgs> {
        _parse(args).map { $0 }
    }
}

private struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol {
    let _parse: ([String]) -> ParsedCmd<T>

    init(_ parser: @escaping ([String]) -> ParsedCmd<T>) {
        self._parse = parser
    }
}
