public struct CloseCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
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
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
