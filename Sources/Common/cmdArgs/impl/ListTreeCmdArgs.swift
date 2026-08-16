public struct ListTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .listTree,
        help: list_tree_help_generated,
        flags: [
            // Filtering flags
            "--focused": trueBoolFlag(\.focused),
            "--workspace": ArgParser(\.workspaces, parseWorkspaces),

            // Formatting flags
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--focused", "--workspace"],
        ],
    )

    public var focused: Bool = false
    public var workspaces: [WorkspaceFilter] = []
    public var json: Bool = false
}

func parseListTreeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListTreeCmdArgs> {
    parseSpecificCmdArgs(ListTreeCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--focused|--workspace)") { raw in
            raw.focused || !raw.workspaces.isEmpty
        }
}
