public struct CloseAllWindowsButCurrentCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .closeAllWindowsButCurrent,
        allowInConfig: true,
        help: """
            USAGE: close-all-windows-but-current [-h|--help] [--quit-if-last-window]

            OPTIONS:
              -h, --help              Print help
              --quit-if-last-window   Quit the apps instead of closing them if it's their last window
            """,
        options: [
            "--quit-if-last-window": trueBoolFlag(\.closeArgs.quitIfLastWindow),
        ],
        arguments: []
    )

    public var closeArgs = CloseCmdArgs(rawArgs: [])
    public var windowId: UInt32?
    public var workspaceName: String?
}

public func parseCloseAllWindowsButCurrentCmdArgs(_ args: [String]) -> ParsedCmd<CloseAllWindowsButCurrentCmdArgs> {
    parseSpecificCmdArgs(CloseAllWindowsButCurrentCmdArgs(rawArgs: .init(args)), args)
}
