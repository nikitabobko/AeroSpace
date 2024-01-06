public struct ListMonitorsCmdArgs: RawCmdArgs, CmdArgs, Equatable {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        allowInConfig: false,
        help: """
              USAGE: list-monitors [-h|--help] [--focused [no]] [--mouse [no]]

              OPTIONS:
                -h, --help       Print help
                --focused [no]   Filter results to only print the focused monitor
                --mouse [no]     Filter results to only print the monitor with the mouse
              """,
        options: [
            "--focused": boolFlag(\.focused),
            "--mouse": boolFlag(\.mouse)
        ],
        arguments: []
    )

    public var focused: Bool?
    public var mouse: Bool?

    public init() {}
}

public func parseListMonitorsCmdArgs(_ args: [String]) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseRawCmdArgs(ListMonitorsCmdArgs(), args)
}
