public struct SetGapsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setGaps,
        allowInConfig: true,
        help: set_gaps_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
            "--outer-left-right": singleValueSubArgParser(\.outerLeftRight, "<size>", { UInt($0) }),
            "--outer-top-bottom": singleValueSubArgParser(\.outerTopBottom, "<size>", { UInt($0) }),
            "--inner": singleValueSubArgParser(\.inner, "<size>", { UInt($0) }),
            "--stdin": trueBoolFlag(\.useStdin),
        ],
        posArgs: [],
    )

    public var outerLeftRight: UInt? = nil
    public var outerTopBottom: UInt? = nil
    public var inner: UInt? = nil
    public var useStdin: Bool = false
}

func parseSetGapsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetGapsCmdArgs> {
    parseSpecificCmdArgs(SetGapsCmdArgs(rawArgs: args), args)
        .filter("At least one gap flag or --stdin must be specified") { cmd in
            cmd.outerLeftRight != nil || cmd.outerTopBottom != nil || cmd.inner != nil || cmd.useStdin
        }
}
