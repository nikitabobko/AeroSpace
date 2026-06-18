public struct FalseCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: ._false,
        help: false_help_generated,
        flags: [:],
        posArgs: [],
    )
    public typealias ExitCodeType = ConditionalExitCode
}
