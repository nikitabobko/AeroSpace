private struct RawMoveNodeToWorkspaceCmdArgs: RawCmdArgs {
    var target: Lateinit<RawWorkspaceTarget> = .uninitialized
    var wrapAroundNextPrev: Bool?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: """
              USAGE: move-node-to-workspace [-h|--help] [--wrap-around] (next|prev)
                 OR: move-node-to-workspace [-h|--help] <workspace-name>

              OPTIONS:
                -h, --help              Print help
                --wrap-around           Make it possible to move nodes between first and last workspaces
                                        (alphabetical order) using (next|prev)

              ARGUMENTS:
                <workspace-name>        Workspace name to move focused window to
              """,
        options: ["--wrap-around": optionalTrueBoolFlag(\.wrapAroundNextPrev)],
        arguments: [newArgParser(\.target, parseRawWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )
}

public struct MoveNodeToWorkspaceCmdArgs: CmdArgs, Equatable {
    public static let info: CmdStaticInfo = RawMoveNodeToWorkspaceCmdArgs.info
    public let target: WorkspaceTarget

    public init(target: WorkspaceTarget) {
        self.target = target
    }
}

public func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseRawCmdArgs(RawMoveNodeToWorkspaceCmdArgs(), args)
        .flatMap { raw in raw.target.val.parse(wrapAround: raw.wrapAroundNextPrev, autoBackAndForth: nil) }
        .flatMap { target in .cmd(MoveNodeToWorkspaceCmdArgs(target: target)) }
}
