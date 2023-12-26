private struct RawWorkspaceCmdArgs: RawCmdArgs {
    var target: Lateinit<RawWorkspaceTarget> = .uninitialized
    var autoBackAndForth: Bool?
    var wrapAroundNextPrev: Bool?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .workspace,
        allowInConfig: true,
        help: """
              USAGE: workspace [-h|--help] [--wrap-around] (next|prev)
                 OR: workspace [-h|--help] [--auto-back-and-forth] <workspace-name>

              OPTIONS:
                -h, --help              Print help
                --auto-back-and-forth   Automatic 'back-and-forth' when switching to already
                                        focused workspace
                --wrap-around           Make it possible to jump between first and last workspaces
                                        (alphabetical order) using (next|prev)

              ARGUMENTS:
                <workspace-name>        Workspace name to focus
              """,
        options: [
            "--auto-back-and-forth": optionalTrueBoolFlag(\.autoBackAndForth),
            "--wrap-around": optionalTrueBoolFlag(\.wrapAroundNextPrev)
        ],
        arguments: [newArgParser(\.target, parseRawWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )
}

public struct WorkspaceCmdArgs: CmdArgs, Equatable {
    public static let info: CmdStaticInfo = RawWorkspaceCmdArgs.info
    public let target: WorkspaceTarget

    public init(
        target: WorkspaceTarget
    ) {
        self.target = target
    }
}

enum RawWorkspaceTarget: Equatable {
    case next
    case prev
    case workspaceName(String)

    func parse(wrapAround: Bool?, autoBackAndForth: Bool?) -> ParsedCmd<WorkspaceTarget> {
        if autoBackAndForth != nil {
            guard case .workspaceName = self else {
                return .failure("--auto-back-and-forth is not allowed for (next|prev)")
            }
        }
        switch self {
        case .next:
            check(autoBackAndForth == nil)
            return .cmd(.next(wrapAround: wrapAround ?? false))
        case .prev:
            check(autoBackAndForth == nil)
            return .cmd(.prev(wrapAround: wrapAround ?? false))
        case .workspaceName(let name):
            if wrapAround != nil {
                return .failure("--wrap-around is allowed only for (next|prev)")
            }
            return .cmd(.workspaceName(name: name, autoBackAndForth: autoBackAndForth ?? false))
        }
    }
}

public enum WorkspaceTarget: Equatable {
    case next(wrapAround: Bool)
    case prev(wrapAround: Bool)
    //case back_and_forth // todo what about 'prev-focused'? todo at least the name needs to be reserved
    case workspaceName(name: String, autoBackAndForth: Bool)

    public func workspaceNameOrNil() -> String? {
        if case .workspaceName(let name, _) = self {
            return name
        } else {
            return nil
        }
    }
}

public func parseWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<WorkspaceCmdArgs> {
    parseRawCmdArgs(RawWorkspaceCmdArgs(), args)
        .flatMap { raw in raw.target.val.parse(wrapAround: raw.wrapAroundNextPrev, autoBackAndForth: raw.autoBackAndForth) }
        .flatMap { target in .cmd(WorkspaceCmdArgs(target: target)) }
}

let workspaceTargetPlaceholder = "(<workspace-name>|next|prev)"

func parseRawWorkspaceTarget(arg: String, nextArgs: inout [String]) -> Parsed<RawWorkspaceTarget> {
    switch arg {
    case "next":
        return .success(.next)
    case "prev":
        return .success(.prev)
    //case "back-and-forth":
    //    return .success(.back_and_forth)
    default:
        return .success(.workspaceName(arg))
    }
}
