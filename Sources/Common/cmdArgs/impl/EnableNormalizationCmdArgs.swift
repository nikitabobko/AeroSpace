public struct EnableNormalizationCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .enableNormalization,
        help: enable_normalization_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--workspace": workspaceSubArgParser(),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.kind, parseNormalizationKind, placeholder: NormalizationKind.unionLiteral),
            newMandatoryPosArgParser(\.targetState, parseNormalizationState, placeholder: EnableNormalizationCmdArgs.State.unionLiteral),
        ],
    )
    public var kind: Lateinit<NormalizationKind> = .uninitialized
    public var targetState: Lateinit<State> = .uninitialized
    public var failIfNoop: Bool = false

    public enum State: String, CaseIterable, Sendable {
        case on, off, toggle, reset
    }
}

func parseEnableNormalizationCmdArgs(_ args: StrArrSlice) -> ParsedCmd<EnableNormalizationCmdArgs> {
    parseSpecificCmdArgs(EnableNormalizationCmdArgs(rawArgs: args), args)
        .filterNot("--fail-if-noop is incompatible with 'toggle' or 'reset' arguments") {
            ($0.targetState.val == .toggle || $0.targetState.val == .reset) && $0.failIfNoop
        }
}

private func parseNormalizationKind(i: PosArgParserInput) -> ParsedCliArgs<NormalizationKind> {
    .init(parseEnum(i.arg, NormalizationKind.self), advanceBy: 1)
}

private func parseNormalizationState(i: PosArgParserInput) -> ParsedCliArgs<EnableNormalizationCmdArgs.State> {
    .init(parseEnum(i.arg, EnableNormalizationCmdArgs.State.self), advanceBy: 1)
}
