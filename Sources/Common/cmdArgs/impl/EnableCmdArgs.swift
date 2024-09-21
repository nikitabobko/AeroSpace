public struct EnableCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .enable,
        allowInConfig: true,
        help: """
            USAGE: enable [-h|--help] toggle
               OR: enable [-h|--help] on [--fail-if-noop]
               OR: enable [-h|--help] off [--fail-if-noop]

            OPTIONS:
              -h, --help       Print help
              --fail-if-noop   Exit with non-zero exit code if already in the requested mode
            """,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.targetState, parseState, mandatoryArgPlaceholder: EnableCmdArgs.State.unionLiteral)]
    )
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var targetState: Lateinit<State> = .uninitialized
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], targetState: State) {
        self.rawArgs = .init(rawArgs)
        self.targetState = .initialized(targetState)
    }

    public enum State: String, CaseIterable {
        case on, off, toggle
    }
}

public func parseEnableCmdArgs(_ args: [String]) -> ParsedCmd<EnableCmdArgs> {
    return parseSpecificCmdArgs(EnableCmdArgs(rawArgs: args), args)
        .filterNot("--fail-if-noop is incompatible with 'toggle' argument") { $0.targetState.val == .toggle && $0.failIfNoop }
}

private func parseState(arg: String, nextArgs: inout [String]) -> Parsed<EnableCmdArgs.State> {
    parseEnum(arg, EnableCmdArgs.State.self)
}
