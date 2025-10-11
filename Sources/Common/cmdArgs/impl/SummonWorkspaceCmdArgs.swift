public struct SummonWorkspaceCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
}

private func parseWorkspaceName(i: ArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    .init(WorkspaceName.parse(i.arg), advanceBy: 1)
}
