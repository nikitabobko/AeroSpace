public func parseCmdArgs(_ args: [String]) -> ParsedCmd<CmdArgs> {
    let subcommand = String(args.first ?? "")
    if subcommand == "" {
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
            result[kind.rawValue] = defaultSubCommandParser(CloseCmdArgs())
        case .closeAllWindowsButCurrent:
            result[kind.rawValue] = defaultSubCommandParser(CloseAllWindowsButCurrentCmdArgs())
        case .debugWindows:
            result[kind.rawValue] = defaultSubCommandParser(DebugWindowsCmdArgs())
        case .enable:
            result[kind.rawValue] = defaultSubCommandParser(EnableCmdArgs())
        case .execAndForget:
            break // exec-and-forget is parsed separately
        case .flattenWorkspaceTree:
            result[kind.rawValue] = defaultSubCommandParser(FlattenWorkspaceTreeCmdArgs())
        case .focus:
            result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
        case .fullscreen:
            result[kind.rawValue] = defaultSubCommandParser(FullscreenCmdArgs())
        case .joinWith:
            result[kind.rawValue] = defaultSubCommandParser(JoinWithCmdArgs())
        case .layout:
            result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
        case .listApps:
            result[kind.rawValue] = defaultSubCommandParser(ListAppsCmdArgs())
        case .listExecEnvVars:
            result[kind.rawValue] = defaultSubCommandParser(ListExecEnvVarsCmdArgs())
        case .listMonitors:
            result[kind.rawValue] = defaultSubCommandParser(ListMonitorsCmdArgs())
        case .listWindows:
            result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
        case .listWorkspaces:
            result[kind.rawValue] = SubCommandParser(parseListWorkspacesCmdArgs)
        case .macosNativeFullscreen:
            result[kind.rawValue] = defaultSubCommandParser(MacosNativeFullscreenCmdArgs())
        case .macosNativeMinimize:
            result[kind.rawValue] = defaultSubCommandParser(MacosNativeMinimizeCmdArgs())
        case .mode:
            result[kind.rawValue] = defaultSubCommandParser(ModeCmdArgs())
        case .moveNodeToWorkspace:
            result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
        case .move:
            result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
            // deprecated
            result["move-through"] = SubCommandParser(parseMoveCmdArgs)
        case .moveWorkspaceToMonitor:
            result[kind.rawValue] = SubCommandParser(parseMoveWorkspaceToMonitorCmdArgs)
            // deprecated
            result["move-workspace-to-display"] = SubCommandParser(parseMoveWorkspaceToMonitorCmdArgs)
        case .reloadConfig:
            result[kind.rawValue] = defaultSubCommandParser(ReloadConfigCmdArgs())
        case .resize:
            result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
        case .split:
            result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
        case .serverVersionInternalCommand:
            if isServer {
                result[kind.rawValue] = defaultSubCommandParser(ServerVersionInternalCommandCmdArgs())
            }
        case .workspace:
            result[kind.rawValue] = SubCommandParser(parseWorkspaceCmdArgs)
        case .workspaceBackAndForth:
            result[kind.rawValue] = defaultSubCommandParser(WorkspaceBackAndForthCmdArgs())
        }
    }
    return result
}

private func defaultSubCommandParser<T: RawCmdArgs>(_ raw: T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw, args) }
}

private let subcommands: [String: any SubCommandParserProtocol] = initSubcommands()

private protocol SubCommandParserProtocol<T> {
    associatedtype T where T: CmdArgs
    var _parse: ([String]) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: [String]) -> ParsedCmd<CmdArgs> {
        _parse(args).map { $0 }
    }
}

private struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol {
    let _parse: ([String]) -> ParsedCmd<T>

    init(_ parser: @escaping ([String]) -> ParsedCmd<T>) {
        self._parse = parser
    }
}
