public struct MoveWindowCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveWindow,
        allowInConfig: true,
        help: move_window_help_generated,
        options: [
            "--window-id": optionalWindowIdFlag(),
            "--focused": trueBoolFlag(\.focused),
        ],
        arguments: [],
    )

    public var focused: Bool = false
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
