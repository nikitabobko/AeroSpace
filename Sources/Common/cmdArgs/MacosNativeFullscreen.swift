public struct MacosNativeFullscreenCmdArgs: CmdArgs, RawCmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeFullscreen,
        allowInConfig: true,
        help: """
              USAGE: macos-native-fullscreen [-h|--help] [on|off]

              OPTIONS:
                -h, --help   Print help

              ARGUMENTS:
                [on|off]     'on' means enter fullscreen mode. 'off' means exit fullscreen mode.
                             Toggle between the two if not specified
              """,
        options: [:],
        arguments: [ArgParser(\.toggle, parseToggleEnum)]
    )
    public var toggle: ToggleEnum = .toggle
}

public enum ToggleEnum {
    case on, off, toggle
}

func parseToggleEnum(arg: String, nextArgs: inout [String]) -> Parsed<ToggleEnum> {
    switch arg {
        case "on":
            return .success(.on)
        case "off":
            return .success(.off)
        default:
            return .failure("Can't parse '\(arg)'. Possible values: on|off")
    }
}
