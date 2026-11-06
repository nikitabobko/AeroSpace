public struct DumpWorkspaceTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .dumpWorkspaceTree,
        help: dump_workspace_tree_help_generated,
        flags: [
            "--all": trueBoolFlag(\.allAlias),
            "--monitor": ArgParser(\.monitors, parseMonitorIds),
            "--workspace": ArgParser(\.workspaces, parseWorkspaces),
        ],
        posArgs: [],
        conflictingFlags: [
            ["--all", "--workspace"],
            ["--all", "--monitor"],
        ],
    )

    fileprivate var allAlias: Bool = false

    public var monitors: [MonitorId] = []
    public var workspaces: [WorkspaceFilter] = []
}

func parseDumpWorkspaceTreeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<DumpWorkspaceTreeCmdArgs> {
    parseSpecificCmdArgs(DumpWorkspaceTreeCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--all|--monitor|--workspace)") { raw in
            raw.allAlias || !raw.monitors.isEmpty || !raw.workspaces.isEmpty
        }
        .map { raw in
            raw.allAlias ? raw.with(\.monitors, [.all]).with(\.allAlias, false) : raw // Normalize alias
        }
}
