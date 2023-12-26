public func parseCmdArgs(_ raw: String) -> ParsedCmd<CmdArgs> {
    if raw == "" {
        return .failure("Can't parse empty string command")
    }
    let subcommand = String(raw.split(separator: " ").first ?? "")
    if (raw.contains("'") || raw.contains("\"") || raw.contains("\\")) && !subcommand.starts(with: "exec") {
        return .failure("Quotation marks and backslash are reserved for future use")
    } else if subcommand == "exec-and-wait" {
        return .failure("DEPRECATED. Please use exec-and-forget in combination with CLI commands")
    } else if let subcommandParser: any SubCommandParserProtocol = subcommands[subcommand] {
        return subcommandParser.parse(args: raw.removePrefix(subcommand))
    } else {
        return .failure("Unrecognized subcommand '\(subcommand)'")
    }
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
        case .listMonitors:
            result[kind.rawValue] = SubCommandParser(parseListMonitorsCmdArgs)
        case .listWorkspaces:
            result[kind.rawValue] = SubCommandParser(parseListWorkspaces)
        case .mode:
            result[kind.rawValue] = SubCommandParser(parseModeCmdArgs)
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
            result[kind.rawValue] = noArgsSubCommandParser(ReloadConfigCmdArgs())
        case .resize:
            result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
        case .split:
            result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
        case .version:
            result[kind.rawValue] = noArgsSubCommandParser(VersionCmdArgs())
            result["-v"] = noArgsSubCommandParser(VersionCmdArgs())
            result["-version"] = noArgsSubCommandParser(VersionCmdArgs())
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
