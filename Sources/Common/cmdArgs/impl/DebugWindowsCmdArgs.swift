public struct DebugWindowsCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        flags: [
            "--window-id": SubArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32)),
        ],
        posArgs: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
