public struct TestCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .test,
        allowInConfig: false,
        help: test_help_generated,
        // Design question: Does --window-id flag compare window ids or checks the conditions against the specified window?
        // Design question: Does --workspace flag compare workspaces or checks the conditions against the specified workspace?
        // Alternative name: --act-on-window-id.
        // Alternative 2: `with-context [--window-id <window-id>] [--workspace <workspace>] <subcommand>` command
        // Alternative 3: `env [name=value]... <subcommand>` command
        // Alternative 4: --window-id and --workspace flags for aerospace top-level command + aerospace subcommand
        flags: [:],
        posArgs: [
            newMandatoryPosArgParser(\.lhs, parseLhs, placeholder: "<lhs>"),
            newMandatoryPosArgParser(\.infixOperator, parseInfixOperator, placeholder: "<operator>"),
            newMandatoryPosArgParser(\.rhs, parseRhs, placeholder: "<rhs>"),
        ],
    )
    public typealias ExitCodeType = ConditionalExitCode

    public var lhs: Lateinit<FormatVar> = .uninitialized
    public var infixOperator: Lateinit<InfixOperator> = .uninitialized
    public var rhs: Lateinit<String> = .uninitialized
}

private func parseRhs(_ input: PosArgParserInput) -> ParsedCliArgs<String> {
    let result = input.arg.interpolationTokens(interpolationChar: "%").flatMap { tokens in
        switch tokens.sequencePattern {
            case .one(.literal(let literal)): .success(literal)
            default: .failure("Right hand side doesn't allow interpolation variables")
        }
    }
    return .init(result, advanceBy: 1)
}

private func parseLhs(_ input: PosArgParserInput) -> ParsedCliArgs<FormatVar> {
    let result = input.arg.interpolationTokens(interpolationChar: "%").flatMap { tokens in
        switch tokens.sequencePattern {
            case .one(.interVar(let interVar)): parseEnum(interVar, FormatVar.self)
            default: .failure("Left hand side must be a single interpolation variable")
        }
    }
    return .init(result, advanceBy: 1)
}

private func parseInfixOperator(_ input: PosArgParserInput) -> ParsedCliArgs<InfixOperator> {
    .init(parseEnum(input.arg, InfixOperator.self), advanceBy: 1)
}

func parseTestCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TestCmdArgs> {
    return parseSpecificCmdArgs(TestCmdArgs(rawArgs: args), args)
}

public enum InfixOperator: String, CaseIterable, Equatable, Sendable {
    case equals = ".="
    case notEquals = "/="

    case matchesRegex = ".~"
    case notMatchesRegex = "/~"

    public enum Reduced: Sendable, Equatable {
        case equals
        case matchesRegex
    }

    public var structured: (Reduced, negated: Bool) {
        switch self {
            case .equals: (.equals, negated: false)
            case .notEquals: (.equals, negated: true)

            case .matchesRegex: (.matchesRegex, negated: false)
            case .notMatchesRegex: (.matchesRegex, negated: true)
        }
    }
}
