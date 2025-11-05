public struct MoveMouseCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveMouse,
        allowInConfig: true,
        help: move_mouse_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.mouseTarget, parseMouseTarget, mandatoryArgPlaceholder: "<mouse-position>")],
    )

    public var failIfNoop: Bool = false
    public var mouseTarget: Lateinit<MouseTarget> = .uninitialized
}

func parseMouseTarget(i: ArgParserInput) -> ParsedCliArgs<MouseTarget> {
    .init(parseEnum(i.arg, MouseTarget.self), advanceBy: 1)
}

public func parseMoveMouseCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveMouseCmdArgs> {
    parseSpecificCmdArgs(MoveMouseCmdArgs(rawArgs: args), args)
        .filter("--fail-if-noop is only compatible with window-lazy-center or monitor-lazy-center") {
            $0.failIfNoop.implies($0.mouseTarget.val == .windowLazyCenter || $0.mouseTarget.val == .monitorLazyCenter)
        }
}

public enum MouseTarget: String, CaseIterable, Sendable {
    case monitorLazyCenter = "monitor-lazy-center"
    case monitorForceCenter = "monitor-force-center"

    case windowLazyCenter = "window-lazy-center"
    case windowForceCenter = "window-force-center"
}
