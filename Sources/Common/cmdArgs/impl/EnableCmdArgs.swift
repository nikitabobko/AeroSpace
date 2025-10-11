public struct EnableCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
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
        self.rawArgsForStrRepr = .init(rawArgs.slice)
        self.targetState = .initialized(targetState)
    }

    public enum State: String, CaseIterable, Sendable {
        case on, off, toggle
    }
}

public func parseEnableCmdArgs(_ args: StrArrSlice) -> ParsedCmd<EnableCmdArgs> {
    return parseSpecificCmdArgs(EnableCmdArgs(rawArgs: args), args)
        .filterNot("--fail-if-noop is incompatible with 'toggle' argument") { $0.targetState.val == .toggle && $0.failIfNoop }
}

private func parseState(i: ArgParserInput) -> ParsedCliArgs<EnableCmdArgs.State> {
    .init(parseEnum(i.arg, EnableCmdArgs.State.self), advanceBy: 1)
}
