public struct CloseCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .close,
        allowInConfig: true,
        help: close_help_generated,
        flags: [
            "--quit-if-last-window": trueBoolFlag(\.quitIfLastWindow),
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [],
    )

    public var quitIfLastWindow: Bool = false
}
