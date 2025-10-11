public struct EnableCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .enable,
        allowInConfig: true,
        help: enable_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.targetState, parseState, mandatoryArgPlaceholder: EnableCmdArgs.State.unionLiteral)],
    )
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var targetState: Lateinit<State> = .uninitialized
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], targetState: State) {
        self.rawArgsForStrRepr = .init(rawArgs)
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
