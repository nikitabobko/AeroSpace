private struct RawWorkspaceCmdArgs: RawCmdArgs {
    var target: WorkspaceTarget?
    var autoBackAndForth: Bool?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: workspace [-h|--help] [--auto-back-and-forth] (next|prev)
                 OR: workspace [-h|--help] [--auto-back-and-forth] <workspace-name>

              OPTIONS:
                -h, --help              Print help
                --auto-back-and-forth   Automatic 'back-and-forth' when switching to already 
                                        focused workspace

              ARGUMENTS:
                <workspace-name>        Workspace name to focus
              """,
        options: [
            "--auto-back-and-forth": trueBoolFlag(\.autoBackAndForth)
        ],
        arguments: [ArgParser(\.target, parseWorkspaceTarget)]
    )
}

struct WorkspaceCmdArgs: CmdArgs, Equatable {
    let kind: CmdKind = .workspace
    let target: WorkspaceTarget
    let autoBackAndForth: Bool
}

enum WorkspaceTarget: Equatable {
    case next
    case prev
    //case back_and_forth // todo what about 'prev-focused'? todo at least the name needs to be reserved
    case workspaceName(String)

    func workspaceNameOrNil() -> String? {
        if case .workspaceName(let name) = self {
            return name
        } else {
            return nil
        }
    }
}

func parseWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<WorkspaceCmdArgs> {
    parseRawCmdArgs(RawWorkspaceCmdArgs(), args)
        .flatMap { raw in
            guard let target = raw.target else {
                return .failure("<workspace-name> is mandatory argument")
            }
            return .cmd(WorkspaceCmdArgs(
                target: target,
                autoBackAndForth: raw.autoBackAndForth ?? false
            ))
        }
}

func parseWorkspaceTarget(_ arg: String) -> Parsed<WorkspaceTarget> {
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
