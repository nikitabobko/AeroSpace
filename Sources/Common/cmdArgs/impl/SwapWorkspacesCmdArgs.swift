public struct SwapWorkspacesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .swapWorkspaces,
        help: swap_workspaces_help_generated,
        flags: [:],
        posArgs: [
            doubleDashArg(mandatory: false),
            newMandatoryPosArgParser(\.workspaceA, parseWorkspaceNamePosArg, placeholder: "<workspace-a>"),
            newMandatoryPosArgParser(\.workspaceB, parseWorkspaceNamePosArg, placeholder: "<workspace-b>"),
        ],
    )

    public var workspaceA: Lateinit<WorkspaceName> = .uninitialized
    public var workspaceB: Lateinit<WorkspaceName> = .uninitialized
}
