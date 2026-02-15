public struct GetTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .getTree,
        allowInConfig: false,
        help: get_tree_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
