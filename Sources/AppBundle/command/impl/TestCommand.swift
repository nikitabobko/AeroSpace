import AppKit
import Common

struct TestCommand: Command {
    let args: TestCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> ConditionalExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }

        let _lhs: Result<Primitive, String> = switch target.windowOrNil {
            case let window?: args.lhs.val.expandFormatVar(obj: .window(try await .resolveWindow(window, for: args.lhs.val)))
            case nil: args.lhs.val.expandFormatVar(obj: .workspace(target.workspace))
        }

        guard let lhs = _lhs.getOrNil(appendErrorTo: &io.stderr) else {
            if target.windowOrNil == nil {
                // The format var likely requires a window context. Report a clearer error.
                io.err(noWindowIsFocused)
            }
            return .fail
        }

        let (infixOperator, negated) = args.infixOperator.val.structured
        let rhs = args.rhs.val
        let lhsType = lhs.kind.rawValue.singleQuoted
        let incompatibleLhsAndOperatorMsg = """
            Interpolation variable: \(args.lhs.val.rawValue.singleQuoted) has type of \(lhsType).
            The \(lhsType) type is not compatible with \(args.infixOperator.val.rawValue.singleQuoted) operator.
            """

        let result: Result<Bool, String> = switch (lhs, infixOperator) {
            case (.bool(let lhs), .equals):
                Bool(rhs).orFailure("Can't convert String \(rhs.singleQuoted) to Bool").map { rhs in lhs == rhs }
            case (.bool, .matchesRegex):
                .failure(incompatibleLhsAndOperatorMsg)
            case (.int(let lhs), .equals):
                Int64(rhs).orFailure("Can't convert String \(rhs.singleQuoted) to Int").map { rhs in lhs == rhs }
            case (.int, .matchesRegex):
                .failure(incompatibleLhsAndOperatorMsg)
            case (.string(let lhs), .equals):
                .success(lhs == rhs)
            case (.string(let lhs), .matchesRegex):
                CaseInsensitiveRegex.new(rhs).map { rhs in lhs.contains(caseInsensitiveRegex: rhs) }
        }

        return switch result {
            case .failure(let err): .fail(io.err(err))
            case .success(true) where negated: ._false
            case .success(true): ._true
            case .success(false) where negated: ._true
            case .success(false): ._false
        }
    }
}
