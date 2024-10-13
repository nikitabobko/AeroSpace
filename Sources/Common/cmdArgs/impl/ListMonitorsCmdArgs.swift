public struct ListMonitorsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        allowInConfig: false,
        help: list_monitors_help_generated,
        options: [
            "--focused": boolFlag(\.focused),
            "--mouse": boolFlag(\.mouse),

            // Formatting flags
            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        arguments: [],
        conflictingOptions: [
            ["--format", "--count"],
            ["--json", "--count"],
        ]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var focused: Bool?
    public var mouse: Bool?
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

public extension ListMonitorsCmdArgs {
    var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .value("monitor-id"), .value("right-padding"), .literal(" | "),
                .value("monitor-name"),
            ]
            : _format
    }
}

public func parseListMonitorsCmdArgs(_ args: [String]) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseSpecificCmdArgs(ListMonitorsCmdArgs(rawArgs: args), args)
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}
