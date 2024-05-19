private struct RawMoveNodeToWorkspaceCmdArgs: RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    var target: Lateinit<RawWorkspaceTarget> = .uninitialized

    // next|prev OPTIONS
    var wrapAroundNextPrev: Bool?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: """
            USAGE: move-node-to-workspace [-h|--help] [--wrap-around] (next|prev)
               OR: move-node-to-workspace [-h|--help] <workspace-name>

            OPTIONS:
              -h, --help              Print help
              --wrap-around           Make it possible to jump between first and last workspaces
                                      using (next|prev)

            ARGUMENTS:
              <workspace-name>        Workspace name to move focused window to
            """,
        options: ["--wrap-around": optionalTrueBoolFlag(\.wrapAroundNextPrev)],
        arguments: [newArgParser(\.target, parseRawWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )
}

public struct MoveNodeToWorkspaceCmdArgs: CmdArgs, Equatable {
    public static let info: CmdStaticInfo = RawMoveNodeToWorkspaceCmdArgs.info
    public let target: WTarget

    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String], _ target: WTarget) {
        self.rawArgs = .init(rawArgs)
        self.target = target
    }
}

public func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseRawCmdArgs(RawMoveNodeToWorkspaceCmdArgs(rawArgs: .init(args)), args)
        .flatMap { raw in raw.target.val.parse(wrapAround: raw.wrapAroundNextPrev, autoBackAndForth: nil) }
        .flatMap { target in .cmd(MoveNodeToWorkspaceCmdArgs(rawArgs: args, target)) }
}
