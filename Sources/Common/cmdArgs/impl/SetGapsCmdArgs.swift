public struct SetGapsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setGaps,
        allowInConfig: true,
        help: set_gaps_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
            "--outer": singleValueSubArgParser(\.outer, "<size>", { UInt($0) }),
            "--inner": singleValueSubArgParser(\.inner, "<size>", { UInt($0) }),
        ],
        posArgs: [],
    )

    public var outer: UInt? = nil
    public var inner: UInt? = nil
}

func parseSetGapsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetGapsCmdArgs> {
    parseSpecificCmdArgs(SetGapsCmdArgs(rawArgs: args), args)
        .filter("At least one of --outer or --inner must be specified") { cmd in
            cmd.outer != nil || cmd.inner != nil
        }
}
