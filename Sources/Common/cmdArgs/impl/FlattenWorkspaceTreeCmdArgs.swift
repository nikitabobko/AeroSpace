public struct FlattenWorkspaceTreeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .flattenWorkspaceTree,
        allowInConfig: true,
        help: flatten_workspace_tree_help_generated,
        options: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
