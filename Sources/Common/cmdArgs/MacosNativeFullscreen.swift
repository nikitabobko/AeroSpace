public struct MacosNativeFullscreenCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeFullscreen,
        allowInConfig: true,
        help: """
            USAGE: macos-native-fullscreen [-h|--help]
               OR: macos-native-fullscreen [-h|--help] [--fail-if-noop] on
               OR: macos-native-fullscreen [-h|--help] [--fail-if-noop] off

            OPTIONS:
              -h, --help       Print help
              --fail-if-noop   Exit with non-zero exit code if already fullscreen or already not fullscreen

            ARGUMENTS:
              on, off          'on' means enter fullscreen mode. 'off' means exit fullscreen mode.
                               Toggle between the two if not specified
            """,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [ArgParser(\.toggle, parseToggleEnum)]
    )

    public var toggle: ToggleEnum = .toggle
    public var failIfNoop: Bool = false
    public var windowId: UInt32?
    public var workspaceName: String?
}

public func parseMacosNativeFullscreenCmdArgs(_ args: [String]) -> ParsedCmd<MacosNativeFullscreenCmdArgs> {
    parseRawCmdArgs(MacosNativeFullscreenCmdArgs(rawArgs: args), args)
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}

public enum ToggleEnum {
    case on, off, toggle
}

func parseToggleEnum(arg: String, nextArgs: inout [String]) -> Parsed<ToggleEnum> {
    return switch arg {
        case "on": .success(.on)
        case "off": .success(.off)
        default: .failure("Can't parse '\(arg)'. Possible values: on|off")
    }
}
