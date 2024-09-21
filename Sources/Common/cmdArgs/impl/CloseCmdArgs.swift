public struct CloseCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
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
            "--quit-if-last-window": trueBoolFlag(\.quitIfLastWindow),
        ],
        arguments: []
    )

    public var quitIfLastWindow: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
