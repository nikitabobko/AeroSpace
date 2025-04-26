public struct WorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .workspace,
        allowInConfig: true,
        help: workspace_help_generated,
        options: [
            "--auto-back-and-forth": optionalTrueBoolFlag(\._autoBackAndForth),
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var target: Lateinit<WorkspaceTarget> = .uninitialized
    public var _autoBackAndForth: Bool?
    public var failIfNoop: Bool = false
    public var _wrapAround: Bool?
}

public func parseWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<WorkspaceCmdArgs> {
    parseSpecificCmdArgs(WorkspaceCmdArgs(rawArgs: args), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--auto-back-and-forth is incompatible with (next|prev)") { $0._autoBackAndForth != nil && $0.target.val.isRelatve }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelatve }
        .filterNot("--fail-if-noop is incompatible with --auto-back-and-forth") { $0.autoBackAndForth && $0.failIfNoop }
}

public extension WorkspaceCmdArgs {
    var wrapAround: Bool { _wrapAround ?? false }
    var autoBackAndForth: Bool { _autoBackAndForth ?? false }
}

public enum WorkspaceTarget: Equatable, Sendable {
    case relative(_ isNext: Bool)
    case direct(WorkspaceName)

    var isDirect: Bool { !isRelatve }
    var isRelatve: Bool { self == .relative(true) || self == .relative(false) }

    public func workspaceNameOrNil() -> WorkspaceName? {
        switch self {
            case .direct(let name): name
            case .relative: nil
        }
    }
}

let workspaceTargetPlaceholder = "(<workspace-name>|next|prev)"

func parseWorkspaceTarget(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceTarget> {
    return switch arg {
        case "next": .success(.relative(true))
        case "prev": .success(.relative(false))
        default: WorkspaceName.parse(arg).map(WorkspaceTarget.direct)
    }
}
