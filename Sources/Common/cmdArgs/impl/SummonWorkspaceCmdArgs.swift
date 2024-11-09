private let actio = "<action>"

public struct SummonWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .summonWorkspace,
        allowInConfig: true,
        help: summon_workspace_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--when-visible": ArgParser(\.rawWhenVisibleAction, upcastArgParserFun(parseWhenVisibleAction)),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceName, mandatoryArgPlaceholder: "<workspace>")]
    )

    public var windowId: UInt32?               // unused
    public var workspaceName: WorkspaceName?   // unused

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

private func parseWorkspaceName(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceName> {
    WorkspaceName.parse(arg)
}

private func parseWhenVisibleAction(arg: String, nextArgs: inout [String]) -> Parsed<SummonWorkspaceCmdArgs.WhenVisible> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, SummonWorkspaceCmdArgs.WhenVisible.self)
    } else {
        return .failure("\(actio) is mandatory")
    }
}
