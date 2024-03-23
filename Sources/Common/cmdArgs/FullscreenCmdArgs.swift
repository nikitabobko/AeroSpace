public struct FullscreenCmdArgs: CmdArgs, RawCmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .fullscreen,
        allowInConfig: true,
        help: """
              USAGE: fullscreen [-h|--help] [on|off]

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
