func parseCmdArgs(_ raw: String) -> ParsedCmd<CmdArgs> {
    if raw == "" {
        return .failure("Can't parse empty string command")
    }
    let subcommand = String(raw.split(separator: " ").first ?? "")
    if (raw.contains("'") || raw.contains("\"")) && !subcommand.starts(with: "exec") {
        return .failure("Quotation marks are reserved for future use")
    }
    if let subcommandParser: any SubCommandParserProtocol = subcommands[subcommand] {
        return subcommandParser.parse(args: raw.removePrefix(subcommand))
    } else {
        return .failure("Unrecognized command '\(raw)'")
    }
}

enum CmdKind: String, CaseIterable, Equatable {
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case enable
    case execAndForget = "exec-and-forget"
    case execAndWait = "exec-and-wait"
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case fullscreen
    case joinWith = "join-with"
    case layout
    case listApps = "list-apps"
    case mode
    case moveNodeToWorkspace = "move-node-to-workspace"
    case moveThrough = "move-through"
    case moveWorkspaceToMonitor = "move-workspace-to-monitor"
    case reloadConfig = "reload-config"
    case resize
    case split
    case version
    case workspace
    case workspaceBackAndForth = "workspace-back-and-forth"
}

private func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
        case .close:
            result[kind.rawValue] = noArgsSubCommandParser(CloseCmdArgs())
        case .closeAllWindowsButCurrent:
            result[kind.rawValue] = noArgsSubCommandParser(CloseAllWindowsButCurrentCmdArgs())
        case .enable:
            result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
        case .execAndForget:
            result[kind.rawValue] = SubCommandParser(parseExecAndForgetCmdArgs)
        case .execAndWait:
            result[kind.rawValue] = SubCommandParser(parseExecAndWaitCmdArgs)
        case .flattenWorkspaceTree:
            result[kind.rawValue] = noArgsSubCommandParser(FlattenWorkspaceTreeCmdArgs())
        case .focus:
            result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
        case .fullscreen:
            result[kind.rawValue] = noArgsSubCommandParser(FullscreenCmdArgs())
        case .joinWith:
            result[kind.rawValue] = SubCommandParser(parseJoinWithCmdArgs)
        case .layout:
            result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
        case .listApps:
            result[kind.rawValue] = noArgsSubCommandParser(ListAppsCmdArgs())
        case .mode:
            result[kind.rawValue] = SubCommandParser(parseModeCmdArgs)
        case .moveNodeToWorkspace:
            result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
        case .moveThrough:
            result[kind.rawValue] = SubCommandParser(parseMoveThroughCmdArgs)
        case .moveWorkspaceToMonitor:
            result[kind.rawValue] = SubCommandParser(parseMoveWorkspaceToMonitorCmdArgs)
            // deprecated
            result["move-workspace-to-display"] = SubCommandParser(parseMoveWorkspaceToMonitorCmdArgs)
        case .reloadConfig:
            result[kind.rawValue] = noArgsSubCommandParser(ReloadConfigCmdArgs())
        case .resize:
            result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
        case .split:
            result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
        case .version:
            result[kind.rawValue] = noArgsSubCommandParser(VersionCmdArgs())
        case .workspace:
            result[kind.rawValue] = SubCommandParser(parseWorkspaceCmdArgs)
        case .workspaceBackAndForth:
            result[kind.rawValue] = noArgsSubCommandParser(WorkspaceBackAndForthCmdArgs())
        }
    }
    return result
}

private func noArgsSubCommandParser<T: RawCmdArgs>(_ raw: T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw, args) }
}

private let subcommands: [String: any SubCommandParserProtocol] = initSubcommands()

private protocol SubCommandParserProtocol<T> {
    associatedtype T where T: CmdArgs
    var _parse: (String) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: String) -> ParsedCmd<CmdArgs> {
        _parse(args).map { $0 }
    }
}

private struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol {
    let _parse: (String) -> ParsedCmd<T>

    init(_ parser: @escaping (String) -> ParsedCmd<T>) {
        self._parse = parser
    }

    init(_ parser: @escaping ([String]) -> ParsedCmd<T>) {
        self._parse = { args in parser(args.split(separator: " ").map { String($0) }) }
    }
}
