public struct MasterStackCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public var cycle: Bool = false
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .masterStack,
        allowInConfig: true,
        help: master_stack_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
            "--cycle": trueBoolFlag(\.cycle),
        ],
        posArgs: [],
    )
}
