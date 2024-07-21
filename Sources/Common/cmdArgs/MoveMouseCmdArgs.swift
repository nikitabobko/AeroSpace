public struct MoveMouseCmdArgs: CmdArgs, RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveMouse,
        allowInConfig: true,
        help: """
            USAGE: move-mouse [-h|--help] <mouse-position>

            OPTIONS:
              -h, --help         Print help

            ARGUMENTS:
              <mouse-position>   Position to move mouse to. See the man page for the possible values.
            """,
        options: [:],
        arguments: [newArgParser(\.mouseTarget, parseMouseTarget, mandatoryArgPlaceholder: "<mouse-position>")]
    )

    public var mouseTarget: Lateinit<MouseTarget> = .uninitialized
}

func parseMouseTarget(arg: String, nextArgs: inout [String]) -> Parsed<MouseTarget> {
    parseEnum(arg, MouseTarget.self)
}

public enum MouseTarget: String, CaseIterable {
    case monitorLazyCenter = "monitor-lazy-center"
    case monitorForceCenter = "monitor-force-center"

    case windowLazyCenter = "window-lazy-center"
    case windowForceCenter = "window-force-center"
}
