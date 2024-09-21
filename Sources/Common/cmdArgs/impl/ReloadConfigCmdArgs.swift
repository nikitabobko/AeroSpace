public struct ReloadConfigCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .reloadConfig,
        allowInConfig: true,
        help: """
            USAGE: reload-config [-h|--help] [--no-gui] [--dry-run]

            OPTIONS:
              -h, --help        Print help
              --no-gui          Don't open GUI to show error. Only use stdout to report errors
              --dry-run         Validate the config and show errors (if any) but don't reload the config
            """,
        options: [
            "--no-gui": trueBoolFlag(\.noGui),
            "--dry-run": trueBoolFlag(\.dryRun),
        ],
        arguments: []
    )

    public var noGui: Bool = false
    public var dryRun: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
