public struct MoveNodeToContainerCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveNodeToContainer,
        help: move_node_to_container_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
        ],
        posArgs: [
            doubleDashArg(mandatory: false),
            newMandatoryPosArgParser(\.targetWorkspace, parseWorkspaceNamePosArg, placeholder: "<workspace-name>"),
            newMandatoryPosArgParser(\.containerPath, parseContainerPathArg, placeholder: "<container-path>"),
            newMandatoryPosArgParser(\.index, parseIndexArg, placeholder: "<index>"),
        ],
    )

    public var focusFollowsWindow: Bool = false
    public var targetWorkspace: Lateinit<WorkspaceName> = .uninitialized
    public var containerPath: Lateinit<ContainerPath> = .uninitialized
    public var index: Lateinit<Int> = .uninitialized
}

private func parseContainerPathArg(i: PosArgParserInput) -> ParsedCliArgs<ContainerPath> {
    .init(ContainerPath.parse(i.arg), advanceBy: 1)
}

private func parseIndexArg(i: PosArgParserInput) -> ParsedCliArgs<Int> {
    if let index = Int(i.arg), index >= 0 {
        return .succ(index, advanceBy: 1)
    } else {
        return .fail("<index> must be a non-negative integer. Got: \(i.arg.singleQuoted)", advanceBy: 1)
    }
}
