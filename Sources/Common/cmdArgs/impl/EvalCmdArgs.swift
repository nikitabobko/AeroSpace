public struct EvalCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .eval,
        help: eval_help_generated,
        flags: [
            "--stdin": ArgParser(\.commonState.explicitStdinFlag, constSubArgParserFun(true)),
        ],
        posArgs: [
            doubleDashArg(mandatory: false),
            newMandatoryPosArgParser(\.shellExpr, consumeStrCliArg, placeholder: "<aerospace-shell-expr>"),
        ],
        conflictingFlags: [],
    )

    public var shellExpr: Lateinit<String> = .uninitialized
    /*conforms*/ public typealias ExitCodeType = Int32ExitCode
}
