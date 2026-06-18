public struct TestCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .test,
        help: test_help_generated,
        // Design question: Does --window-id flag compare window ids or checks the conditions against the specified window?
        // Design question: Does --workspace flag compare workspaces or checks the conditions against the specified workspace?
        // Alternative name: --act-on-window-id.
        // Alternative 2: `with-context [--window-id <window-id>] [--workspace <workspace>] <subcommand>` command
        // Alternative 3: `env [name=value]... <subcommand>` command
        // Alternative 4: --window-id and --workspace flags for aerospace top-level command + aerospace subcommand
        flags: [:],
        posArgs: [
            newMandatoryPosArgParser(\.lhs, parseTestLhs, placeholder: "<lhs>"),
            newMandatoryPosArgParser(\.infixOperator, parseTestInfixOperator, placeholder: "<operator>"),
            newMandatoryPosArgParser(\.rhs, parseTestRhs, placeholder: "<rhs>"),
        ],
    )
    public typealias ExitCodeType = ConditionalExitCode

    public var lhs: Lateinit<FormatVar> = .uninitialized
    public var infixOperator: Lateinit<InfixOperator> = .uninitialized
    public var rhs: Lateinit<String> = .uninitialized
}

func parseTestRhs(_ input: PosArgParserInput) -> ParsedCliArgs<String> {
    let result = input.arg.rawInterpolationTokens(interpolationChar: "%").flatMap { tokens in
        switch tokens.sequencePattern {
            case .one(.literal(let literal)): .success(literal)
            default: .failure("Right hand side doesn't allow interpolation variables")
        }
    }
    return .init(result, advanceBy: 1)
}

func parseTestLhs(_ input: PosArgParserInput) -> ParsedCliArgs<FormatVar> {
    let result = input.arg.interpolationTokens(interpolationChar: "%", ofInterVarType: FormatVar.self).flatMap { tokens in
        switch tokens.sequencePattern {
            case .one(.interVar(let formatVar)): .success(formatVar)
            default: .failure("Left hand side must be a single interpolation variable")
        }
    }
    return .init(result, advanceBy: 1)
}

func parseTestInfixOperator(_ input: PosArgParserInput) -> ParsedCliArgs<InfixOperator> {
    .init(parseEnum(input.arg, InfixOperator.self), advanceBy: 1)
}

func parseTestCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TestCmdArgs> {
    return parseSpecificCmdArgs(TestCmdArgs(rawArgs: args), args)
}

public enum InfixOperator: String, CaseIterable, Equatable, Sendable {
    case equals = "="
    case matchesRegex = "~="
}
