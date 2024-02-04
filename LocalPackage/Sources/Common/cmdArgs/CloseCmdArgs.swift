public struct CloseCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .close,
        allowInConfig: true,
        help: """
              USAGE: close [-h|--help] [--quit-if-last-window]

              OPTIONS:
                -h, --help              Print help
                --quit-if-last-window   Quit the app instead of closing if it's the last window of the app
              """,
        options: [
            "--quit-if-last-window": trueBoolFlag(\.quitIfLastWindow)
        ],
        arguments: []
    )

    public var quitIfLastWindow: Bool = false
}

public func parseCloseCmdArgs(_ args: [String]) -> ParsedCmd<CloseCmdArgs> {
    parseRawCmdArgs(CloseCmdArgs(), args)
}
