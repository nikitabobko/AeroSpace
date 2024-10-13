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
            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
        ],
        arguments: [],
        conflictingOptions: [
            ["--format", "--count"],
        ]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var focused: Bool?
    public var mouse: Bool?
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
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
