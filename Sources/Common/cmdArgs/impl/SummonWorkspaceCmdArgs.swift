public struct SummonWorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .summonWorkspace,
        help: summon_workspace_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--when-visible": ArgParser(\.rawWhenVisibleAction, upcastArgParserFun(parseWhenVisibleAction)),
        ],
        posArgs: [
            doubleDashArg(mandatory: false),
            newMandatoryPosArgParser(\.target, parseWorkspaceName, placeholder: "<workspace>"),
        ],
    )

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
    public var rawWhenVisibleAction: WhenVisible? = nil

    public enum WhenVisible: String, CaseIterable, Equatable, Sendable {
        case move = "move"
        case focus = "focus"
        case swap = "swap"
    }
}

extension SummonWorkspaceCmdArgs {
    public var whenVisible: WhenVisible { rawWhenVisibleAction ?? .move }
}

private func parseWorkspaceName(i: PosArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    .init(WorkspaceName.parse(i.arg), advanceBy: 1)
}

private func parseWhenVisibleAction(i: SubArgParserInput) -> ParsedCliArgs<SummonWorkspaceCmdArgs.WhenVisible> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, SummonWorkspaceCmdArgs.WhenVisible.self), advanceBy: 1)
    } else {
        return .fail("<action> is mandatory", advanceBy: 0)
    }
}
