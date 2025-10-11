public struct DebugWindowsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        options: [
            "--window-id": SubArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32)),
        ],
        arguments: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
