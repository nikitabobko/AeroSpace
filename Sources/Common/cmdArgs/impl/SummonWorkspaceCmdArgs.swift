public struct SummonWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: workspace_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")]
    )

    public var windowId: UInt32?               // unused
    public var workspaceName: WorkspaceName?   // unused

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
}

private func parseWorkspaceName(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceName> {
    WorkspaceName.parse(arg)
}
