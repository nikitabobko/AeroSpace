public struct CommandCenterCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .commandCenter,
        help: command_center_help_generated,
        flags: [:],
        posArgs: [],
    )
}
