public struct ListModesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listModes,
        allowInConfig: false,
        help: list_modes_help_generated,
        flags: [
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--current": trueBoolFlag(\.current),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--current"],
            ["--count", "--json"],
        ],
    )

    public var current: Bool = false
    public var json: Bool = false
    public var outputOnlyCount: Bool = false
}

public func parseListModesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListModesCmdArgs> {
    parseSpecificCmdArgs(ListModesCmdArgs(rawArgs: args), args)
}
