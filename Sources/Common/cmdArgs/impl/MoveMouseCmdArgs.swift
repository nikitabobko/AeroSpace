public struct MoveMouseCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveMouse,
        allowInConfig: true,
        help: move_mouse_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [newArgParser(\.mouseTarget, parseMouseTarget, mandatoryArgPlaceholder: "<mouse-position>")]
    )

    public var failIfNoop: Bool = false
    public var mouseTarget: Lateinit<MouseTarget> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}

func parseMouseTarget(arg: String, nextArgs: inout [String]) -> Parsed<MouseTarget> {
    parseEnum(arg, MouseTarget.self)
}

public func parseMoveMouseCmdArgs(_ args: [String]) -> ParsedCmd<MoveMouseCmdArgs> {
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
