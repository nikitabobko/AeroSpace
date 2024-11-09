public struct SummonWorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--when-visible": SubArgParser(\.rawWhenVisibleAction, upcastSubArgParserFun(parseWhenVisibleAction)),
        ],
        posArgs: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")],
    )

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
    public var rawWhenVisibleAction: WhenVisible? = nil

    public enum WhenVisible: String, CaseIterable, Equatable, Sendable {
        case focus = "focus"
        case swap = "swap"
    }
}

extension SummonWorkspaceCmdArgs {
    public var whenVisible: WhenVisible { rawWhenVisibleAction ?? .focus }
}

private func parseWorkspaceName(i: ArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    .init(WorkspaceName.parse(i.arg), advanceBy: 1)
}

private func parseWhenVisibleAction(i: SubArgParserInput) -> ParsedCliArgs<SummonWorkspaceCmdArgs.WhenVisible> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, SummonWorkspaceCmdArgs.WhenVisible.self), advanceBy: 1)
    } else {
        return .fail("<action> is mandatory", advanceBy: 0)
    }
}
