public struct ReloadConfigCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .reloadConfig,
        help: reload_config_help_generated,
        flags: [
            "--no-gui": trueBoolFlag(\.noGui),
            "--dry-run": trueBoolFlag(\.dryRun),
            "--warnings-as-errors": trueBoolFlag(\.warningsAsErrors),
        ],
        posArgs: [],
    )

    public var noGui: Bool = false
    public var dryRun: Bool = false
    public var warningsAsErrors: Bool = false
}
