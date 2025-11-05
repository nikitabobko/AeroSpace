public struct SplitCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .split,
        allowInConfig: true,
        help: split_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.arg, parseSplitArg, mandatoryArgPlaceholder: SplitArg.unionLiteral)],
    )

    public var arg: Lateinit<SplitArg> = .uninitialized

    public init(rawArgs: [String], _ arg: SplitArg) {
        self.commonState = .init(rawArgs.slice)
        self.arg = .initialized(arg)
    }

    public enum SplitArg: String, CaseIterable, Sendable {
        case horizontal, vertical, opposite
    }
}

public func parseSplitCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SplitCmdArgs> {
    parseSpecificCmdArgs(SplitCmdArgs(rawArgs: args), args)
}

private func parseSplitArg(i: ArgParserInput) -> ParsedCliArgs<SplitCmdArgs.SplitArg> {
    .init(parseEnum(i.arg, SplitCmdArgs.SplitArg.self), advanceBy: 1)
}
