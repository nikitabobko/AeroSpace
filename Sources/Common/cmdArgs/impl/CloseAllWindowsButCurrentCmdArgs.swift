public struct CloseAllWindowsButCurrentCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
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
}

public func parseCloseAllWindowsButCurrentCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CloseAllWindowsButCurrentCmdArgs> {
    parseSpecificCmdArgs(CloseAllWindowsButCurrentCmdArgs(rawArgs: args), args)
}
