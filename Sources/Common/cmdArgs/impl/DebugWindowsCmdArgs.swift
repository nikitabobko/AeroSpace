public struct DebugWindowsCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        flags: [
            "--window-id": SubArgParser(\.windowId, upcastSubArgParserFun(parseUInt32SubArg)),
        ],
        posArgs: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
