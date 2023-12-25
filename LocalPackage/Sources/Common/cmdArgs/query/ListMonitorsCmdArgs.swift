public struct ListMonitorsCmdArgs: RawCmdArgs, CmdArgs, Equatable {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        allowInConfig: false,
        help: """
              USAGE: list-monitors [-h|--help] [--focused] [--mouse]

              OPTIONS:
                -h, --help   Print help
                --focused    Only print the focused monitor
                --mouse      Only print the monitor with the mouse
              """,
        options: [
            "--focused": trueBoolFlag(\.focused),
            "--mouse": trueBoolFlag(\.mouse)
        ],
        arguments: []
    )

    public var focused: Bool? = false
    public var mouse: Bool? = false

    public init() {}
}

public func parseListMonitorsCmdArgs(_ args: [String]) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseRawCmdArgs(ListMonitorsCmdArgs(), args)
}
