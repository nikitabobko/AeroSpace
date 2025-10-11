public struct ReloadConfigCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .reloadConfig,
        allowInConfig: true,
        help: reload_config_help_generated,
        flags: [
            "--no-gui": trueBoolFlag(\.noGui),
            "--dry-run": trueBoolFlag(\.dryRun),
        ],
        posArgs: [],
    )

    public var noGui: Bool = false
    public var dryRun: Bool = false
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
