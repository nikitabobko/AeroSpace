public struct SummonWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
}

private func parseWorkspaceName(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceName> {
    WorkspaceName.parse(arg)
}
