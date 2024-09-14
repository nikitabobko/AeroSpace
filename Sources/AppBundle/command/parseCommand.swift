import Common
import TOMLKit

func parseCommand(_ raw: String) -> ParsedCmd<any Command> {
    if raw.starts(with: "exec-and-forget") {
        return .cmd(ExecAndForgetCommand(args: ExecAndForgetCmdArgs(bashScript: raw.removePrefix("exec-and-forget"))))
    }
    return switch raw.splitArgs() {
        case .success(let args): parseCommand(args)
        case .failure(let fail): .failure(fail)
    }
}

func parseCommand(_ args: [String]) -> ParsedCmd<any Command> {
    parseCmdArgs(args).map { $0.toCommand() }
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType) -> String {
    "Expected type is '\(expected)'. But actual type is '\(actual)'"
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType) -> String {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual)
    } else {
        return "Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}
