public struct MoveNodeToWorkspaceCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public var target: Lateinit<WorkspaceTarget> = .uninitialized
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToWorkspace,
        allowInConfig: true,
        help: """
            USAGE: move-node-to-workspace [-h|--help] [--wrap-around] (next|prev)
               OR: move-node-to-workspace [-h|--help] [--fail-if-noop] <workspace-name>

            OPTIONS:
              -h, --help              Print help
              --wrap-around           Make it possible to jump between first and last workspaces
                                      using (next|prev)
              --fail-if-noop          Exit with non-zero code if move window to workspace it already belongs to

            ARGUMENTS:
              <workspace-name>        Workspace name to move focused window to
            """,
        options: [
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)]
    )

    public var _wrapAround: Bool?
    public var failIfNoop: Bool = false
    public var windowId: UInt32?
    public var workspaceName: String?

    public init(rawArgs: [String]) {
        self.rawArgs = .init(rawArgs)
    }
}

public extension MoveNodeToWorkspaceCmdArgs {
    var wrapAround: Bool { _wrapAround ?? false }
}

func implication(ifTrue: Bool, mustHold: @autoclosure () -> Bool) -> Bool { !ifTrue || mustHold() }

public func parseMoveNodeToWorkspaceCmdArgs(_ args: [String]) -> ParsedCmd<MoveNodeToWorkspaceCmdArgs> {
    parseRawCmdArgs(MoveNodeToWorkspaceCmdArgs(rawArgs: .init(args)), args)
        .filter("--wrapAround requires using (prev|next) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelatve) }
        .filterNot("--fail-if-noop is incompatible with (next|prev)") { $0.failIfNoop && $0.target.val.isRelatve }
}
