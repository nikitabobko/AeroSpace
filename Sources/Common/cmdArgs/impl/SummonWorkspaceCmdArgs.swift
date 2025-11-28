private let actio = "<action>"

public struct SummonWorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--when-visible": ArgParser(\.rawWhenVisibleAction, upcastArgParserFun(parseWhenVisibleAction)),
        ],
        posArgs: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")],
    )

    public var target: Lateinit<WorkspaceName> = .uninitialized
    public var failIfNoop: Bool = false
    public var rawWhenVisibleAction: WhenVisible? = nil

    public enum WhenVisible: String, CaseIterable, Equatable {
        case focus = "focus"
        case swap = "swap"
    }
}

public extension SummonWorkspaceCmdArgs {
    var whenVisible: WhenVisible { rawWhenVisibleAction ?? .focus }
}

private func parseWorkspaceName(i: ArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    .init(WorkspaceName.parse(i.arg), advanceBy: 1)
}

private func parseWhenVisibleAction(arg: String, nextArgs: inout [String]) -> Parsed<SummonWorkspaceCmdArgs.WhenVisible> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, SummonWorkspaceCmdArgs.WhenVisible.self)
    } else {
        return .failure("\(actio) is mandatory")
    }
}
