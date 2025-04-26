public struct ListModesCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) {
        self.rawArgs = .init(rawArgs)
    }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listModes,
        allowInConfig: false,
        help: list_modes_help_generated,
        options: [
            "--current": trueBoolFlag(\.current),
        ],
        arguments: []
    )

    public var windowId: UInt32?               // unused
    public var workspaceName: WorkspaceName?   // unused
    public var current: Bool = false
}

public func parseListModesCmdArgs(_ args: [String]) -> ParsedCmd<ListModesCmdArgs> {
    parseSpecificCmdArgs(ListModesCmdArgs(rawArgs: args), args)
}
