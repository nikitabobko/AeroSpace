public struct DebugWindowsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: EquatableNoop<[String]>) { self.rawArgs = rawArgs }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindows,
        allowInConfig: false,
        help: debug_windows_help_generated,
        options: [
            "--window-id": ArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32)),
        ],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
