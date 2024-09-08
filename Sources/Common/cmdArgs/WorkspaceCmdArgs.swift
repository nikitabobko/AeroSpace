public struct WorkspaceCmdArgs: RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public var target: Lateinit<WorkspaceTarget> = .uninitialized

    // direct workspace target OPTIONS
    public var _autoBackAndForth: Bool?

    // next|prev OPTIONS
    public var _wrapAround: Bool?

    public init(rawArgs: [String]) {
        self.rawArgs = .init(rawArgs)
    }

    public static let parser: CmdParser<Self> = cmdParser(
        kind: .workspace,
        allowInConfig: true,
        help: """
            USAGE: workspace [-h|--help] [--auto-back-and-forth] <workspace-name>
               OR: workspace [-h|--help] [--wrap-around] (next|prev)

            OPTIONS:
              -h, --help              Print help
              --auto-back-and-forth   Automatic 'back-and-forth' when switching to already
                                      focused workspace
              --wrap-around           Make it possible to jump between first and last workspaces
                                      using (next|prev)

            ARGUMENTS:
              <workspace-name>        Workspace name to focus
            """,
        options: [
            "--auto-back-and-forth": optionalTrueBoolFlag(\._autoBackAndForth),
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )
}

public extension WorkspaceCmdArgs {
    var wrapAround: Bool { _wrapAround ?? false }
    var autoBackAndForth: Bool { _autoBackAndForth ?? false }
}

public enum WorkspaceTarget: Equatable {
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

public func parseWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<WorkspaceCmdArgs> {
    parseRawCmdArgs(WorkspaceCmdArgs(rawArgs: args), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--auto-back-and-forth is incompatible with (next|prev)") { $0._autoBackAndForth != nil && $0.target.val.isRelatve }
}

let workspaceTargetPlaceholder = "(<workspace-name>|next|prev)"

func parseWorkspaceTarget(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceTarget> {
    return switch arg {
        case "next": .success(.relative(true))
        case "prev": .success(.relative(false))
        default: WorkspaceName.parse(arg).map(WorkspaceTarget.direct)
    }
}
