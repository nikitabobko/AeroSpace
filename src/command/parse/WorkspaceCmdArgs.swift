private struct RawWorkspaceCmdArgs: RawCmdArgs {
    var target: WorkspaceTarget?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: workspace [-h|--help] (next|prev)
                 OR: workspace [-h|--help] <workspace-name>

              OPTIONS:
                -h, --help              Print help

              ARGUMENTS:
                <workspace-name>        Workspace name to focus
              """,
        options: [:],
        arguments: [ArgParser(\.target, parseWorkspaceTarget)]
    )
}

struct WorkspaceCmdArgs: CmdArgs, Equatable {
    let kind: CmdKind = .workspace
    let target: WorkspaceTarget
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
                target: target
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
