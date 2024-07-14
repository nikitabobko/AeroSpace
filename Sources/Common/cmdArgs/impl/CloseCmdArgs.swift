public struct CloseCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .close,
        allowInConfig: true,
        help: close_help_generated,
        options: [
            "--quit-if-last-window": trueBoolFlag(\.quitIfLastWindow),
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: []
    )

    public var quitIfLastWindow: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
