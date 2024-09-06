public struct FullscreenCmdArgs: CmdArgs, RawCmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .fullscreen,
        allowInConfig: true,
        help: """
            USAGE: fullscreen [-h|--help] [--no-outer-gaps]
               OR: fullscreen [-h|--help] on [--no-outer-gaps] [--fail-if-noop]
               OR: fullscreen [-h|--help] off [--fail-if-noop]

            OPTIONS:
              -h, --help        Print help
              --no-outer-gaps   Remove the outer gaps when in fullscreen mode
              --fail-if-noop    Exit with non-zero exit code if already fullscreen or already not fullscreen

            ARGUMENTS:
              on, off           'on' means enter fullscreen mode. 'off' means exit fullscreen mode.
                                Toggle between the two if not specified
            """,
        options: [
            "--no-outer-gaps": trueBoolFlag(\.noOuterGaps),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        arguments: [ArgParser(\.toggle, parseToggleEnum)]
    )

    public var toggle: ToggleEnum = .toggle
    public var noOuterGaps: Bool = false
    public var failIfNoop: Bool = false
}

public func parseFullscreenCmdArgs(_ args: [String]) -> ParsedCmd<FullscreenCmdArgs> {
    parseRawCmdArgs(FullscreenCmdArgs(rawArgs: args), args)
        .filterNot("--no-outer-gaps is incompatible with 'off' argument") { $0.toggle == .off && $0.noOuterGaps }
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}
