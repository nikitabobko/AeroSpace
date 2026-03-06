public struct ListMonitorsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        allowInConfig: false,
        help: list_monitors_help_generated,
        flags: [
            "--focused": boolFlag(\.focused),
            "--mouse": boolFlag(\.mouse),

            // Formatting flags
            "--format": formatParser(\._format, for: .monitor),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

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

public func parseListMonitorsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListMonitorsCmdArgs> {
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
