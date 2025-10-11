public struct ListModesCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    public init(rawArgs: [String]) {
        self.rawArgsForStrRepr = .init(rawArgs)
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

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var current: Bool = false
    public var json: Bool = false
    public var outputOnlyCount: Bool = false
}

public func parseListModesCmdArgs(_ args: [String]) -> ParsedCmd<ListModesCmdArgs> {
    parseSpecificCmdArgs(ListModesCmdArgs(rawArgs: args), args)
}
