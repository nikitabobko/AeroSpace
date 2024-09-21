public struct WorkspaceBackAndForthCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .workspaceBackAndForth,
        allowInConfig: true,
        help: workspace_back_and_forth_help_generated,
        options: [:],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
