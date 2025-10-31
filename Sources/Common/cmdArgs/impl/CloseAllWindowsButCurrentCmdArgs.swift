public struct CloseAllWindowsButCurrentCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .closeAllWindowsButCurrent,
        allowInConfig: true,
        help: close_all_windows_but_current_help_generated,
        flags: [
            "--quit-if-last-window": trueBoolFlag(\.closeArgs.quitIfLastWindow),
        ],
        posArgs: [],
    )

    public var closeArgs = CloseCmdArgs(rawArgs: [])
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

public func parseCloseAllWindowsButCurrentCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CloseAllWindowsButCurrentCmdArgs> {
    parseSpecificCmdArgs(CloseAllWindowsButCurrentCmdArgs(rawArgs: args), args)
}
