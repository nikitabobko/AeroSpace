public struct TestNotCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .testNot,
        help: test_not_help_generated,
        flags: [:],
        posArgs: [],
    )
    public typealias ExitCodeType = ConditionalExitCode

    public var testArgs = TestCmdArgs(rawArgs: [])
}

func parseTestNotCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TestNotCmdArgs> {
    parseSpecificCmdArgs(TestCmdArgs(rawArgs: args), args).map {
        TestNotCmdArgs(rawArgs: args).copy(\.testArgs, $0)
    }
}
