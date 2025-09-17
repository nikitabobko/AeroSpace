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

            "--stdin": optionalTrueBoolFlag(\.explicitStdinFlag),
            "--no-stdin": optionalFalseBoolFlag(\.explicitStdinFlag),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var target: Lateinit<WorkspaceTarget> = .uninitialized
    public var _autoBackAndForth: Bool?
    public var failIfNoop: Bool = false
    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
}

public func parseWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<WorkspaceCmdArgs> {
    parseSpecificCmdArgs(WorkspaceCmdArgs(rawArgs: args), args)
        .filter("--wrapAround requires using \(NextPrev.unionLiteral) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--auto-back-and-forth is incompatible with \(NextPrev.unionLiteral)") { $0._autoBackAndForth != nil && $0.target.val.isRelatve }
        .filterNot("--fail-if-noop is incompatible with \(NextPrev.unionLiteral)") { $0.failIfNoop && $0.target.val.isRelatve }
        .filterNot("--fail-if-noop is incompatible with --auto-back-and-forth") { $0.autoBackAndForth && $0.failIfNoop }
        .filter("--stdin and --no-stdin require using \(NextPrev.unionLiteral) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelatve) }
}

extension WorkspaceCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var autoBackAndForth: Bool { _autoBackAndForth ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

public enum WorkspaceTarget: Equatable, Sendable {
    case relative(NextPrev)
    case direct(WorkspaceName)

    var isDirect: Bool { !isRelatve }
    var isRelatve: Bool {
        switch self {
            case .relative: true
            default: false
        }
    }

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
        case "next": .success(.relative(.next))
        case "prev": .success(.relative(.prev))
        default: WorkspaceName.parse(arg).map(WorkspaceTarget.direct)
    }
}
