public struct DebugWindowsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        flags: [
            "--window-id": SubArgParser(\.windowId, upcastSubArgParserFun(parseUInt32SubArg)),
        ],
        posArgs: [],
    )
}
