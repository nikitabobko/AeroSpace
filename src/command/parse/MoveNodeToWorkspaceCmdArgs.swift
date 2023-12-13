private struct RawMoveNodeToWorkspaceCmdArgs: RawCmdArgs {
    var target: WorkspaceTarget?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: move-node-to-workspace [-h|--help] (next|prev)
                 OR: move-node-to-workspace [-h|--help] <workspace-name>

              OPTIONS:
                -h, --help              Print help

              ARGUMENTS:
                <workspace-name>        Workspace name to move focused window to
              """,
        options: [:],
        arguments: [ArgParser(\.target, parseWorkspaceTarget)]
    )
}

struct MoveNodeToWorkspaceCmdArgs: CmdArgs, Equatable {
    let kind: CmdKind = .moveNodeToWorkspace
    let target: WorkspaceTarget
}

func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseRawCmdArgs(RawMoveNodeToWorkspaceCmdArgs(), args)
        .flatMap { raw in
            guard let target = raw.target else {
                return .failure("<workspace-name> is mandatory argument")
            }
            return .cmd(MoveNodeToWorkspaceCmdArgs(
                target: target
            ))
        }
}
