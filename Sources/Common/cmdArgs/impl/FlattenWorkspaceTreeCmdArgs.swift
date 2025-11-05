public struct FlattenWorkspaceTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .flattenWorkspaceTree,
        allowInConfig: true,
        help: flatten_workspace_tree_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
