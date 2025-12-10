public struct FocusBackAndForthCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focusBackAndForth,
        allowInConfig: true,
        help: focus_back_and_forth_help_generated,
        flags: [:],
        posArgs: [],
    )
}
