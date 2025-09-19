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
            "--format": formatParser(\._format, for: .monitor),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        arguments: [],
        conflictingOptions: [
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var focused: Bool?
    public var mouse: Bool?
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

extension ListMonitorsCmdArgs {
    public var format: [StringInterToken] {
        if _format.isEmpty {
            return [
                .interVar("monitor-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("monitor-name"),
            ]
        }
        if _format.contains(.interVar(PlainInterVar.all.rawValue)) {
            return AeroObjKind.monitor.getFormatWithAllVariable()
        }
        return _format
    }
}

public func parseListMonitorsCmdArgs(_ args: [String]) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseSpecificCmdArgs(ListMonitorsCmdArgs(rawArgs: args), args)
        .flatMap { parsed in
            if parsed.json, let msg = getErrorIfFormatIsIncompatibleWithJson(parsed._format) {
                return .failure(msg)
            }
            if let msg = getErrorIfAllFormatVariableIsInvalid(json: parsed.json, format: parsed._format) {
                return .failure(msg)
            }
            return .cmd(parsed)
        }
}
