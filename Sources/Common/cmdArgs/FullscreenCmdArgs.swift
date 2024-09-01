public struct FullscreenCmdArgs: CmdArgs, RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .fullscreen,
        allowInConfig: true,
        help: """
            USAGE: fullscreen [-h|--help] [--no-outer-gaps] [on]
               OR: fullscreen [-h|--help] off

            OPTIONS:
              -h, --help        Print help
              --no-outer-gaps   Remove the outer gaps when in fullscreen mode

            ARGUMENTS:
              [on|off]     'on' means enter fullscreen mode. 'off' means exit fullscreen mode.
                           Toggle between the two if not specified
            """,
        options: [
            "--no-outer-gaps": trueBoolFlag(\.noOuterGaps)
        ],
        arguments: [ArgParser(\.toggle, parseToggleEnum)]
    )

    public var toggle: ToggleEnum = .toggle
    public var noOuterGaps: Bool = false
}

public func parseFullscreenCmdArgs(_ args: [String]) -> ParsedCmd<FullscreenCmdArgs> {
    return parseRawCmdArgs(FullscreenCmdArgs(rawArgs: args), args)
        .filter("--no-outer-gaps is incompatible with node off") { $0.toggle != .off || $0.noOuterGaps != true }
}
