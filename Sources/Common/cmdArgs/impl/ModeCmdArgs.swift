public struct ModeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .mode,
        allowInConfig: true,
        help: mode_help_generated,
        flags: [:],
        posArgs: [newArgParser(\.targetMode, consumeStrCliArg, mandatoryArgPlaceholder: "<binding-mode>")],
    )

    public var targetMode: Lateinit<String> = .uninitialized
}

func consumeStrCliArg(i: ArgParserInput) -> ParsedCliArgs<String> { .succ(i.arg, advanceBy: 1) }
