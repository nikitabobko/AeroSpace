public struct ListMonitorsCmdArgs: RawCmdArgs, CmdArgs, Equatable {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        allowInConfig: false,
        help: """
            USAGE: list-monitors [-h|--help] [--focused [no]] [--mouse [no]] [--format <output-format>]

            OPTIONS:
              -h, --help                 Print help
              --focused [no]             Filter results to only print the focused monitor
              --mouse [no]               Filter results to only print the monitor with the mouse
              --format <output-format>   Specify output format
            """,
        options: [
            "--focused": boolFlag(\.focused),
            "--mouse": boolFlag(\.mouse),
            "--format": ArgParser(\.format, parseFormat),
        ],
        arguments: []
    )

    public var focused: Bool?
    public var mouse: Bool?
    public var format: [StringInterToken] = [
        .value("monitor-id"), .value("right-padding"), .literal(" | "),
        .value("monitor-name"),
    ]

    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
}
