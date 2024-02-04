public struct ListAppsCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listApps,
        allowInConfig: false,
        help: """
              USAGE: list-apps [-h|--help] [--macos-hidden [no]]

              OPTIONS:
                -h, --help           Print help
                --macos-hidden [no]  Filter results to only print (not) hidden applications
              """,
        options: [
            "--macos-hidden": boolFlag(\.macosHidden),
        ],
        arguments: []
    )

    public var macosHidden: Bool?
}

public func parseListAppsCmdArgs(_ args: [String]) -> ParsedCmd<ListAppsCmdArgs> {
    parseRawCmdArgs(ListAppsCmdArgs(), args)
}
