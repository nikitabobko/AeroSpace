public struct EnableCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .enable,
        allowInConfig: true,
        help: enable_help_generated,
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

    public enum State: String, CaseIterable, Sendable {
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
