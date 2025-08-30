public struct CloseAllWindowsButCurrentCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .closeAllWindowsButCurrent,
        allowInConfig: true,
        help: close_all_windows_but_current_help_generated,
        options: [
            "--quit-if-last-window": trueBoolFlag(\.closeArgs.quitIfLastWindow),
        ],
        arguments: [],
    )

    public var closeArgs = CloseCmdArgs(rawArgs: [])
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

public func parseCloseAllWindowsButCurrentCmdArgs(_ args: [String]) -> ParsedCmd<CloseAllWindowsButCurrentCmdArgs> {
    parseSpecificCmdArgs(CloseAllWindowsButCurrentCmdArgs(rawArgs: args), args)
}
