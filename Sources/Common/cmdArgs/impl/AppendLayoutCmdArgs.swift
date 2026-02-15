public struct AppendLayoutCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .appendLayout,
        allowInConfig: false,
        help: append_layout_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
