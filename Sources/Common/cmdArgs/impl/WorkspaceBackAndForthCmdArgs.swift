public struct WorkspaceBackAndForthCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = noArgsParser(.workspaceBackAndForth, allowInConfig: true)

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
