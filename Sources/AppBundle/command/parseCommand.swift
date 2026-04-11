import Common

func parseCommand(_ raw: String) -> ParsedCmd<any Command> {
    if raw.starts(with: "exec-and-forget") {
        return .cmd(ExecAndForgetCommand(args: ExecAndForgetCmdArgs(bashScript: raw.removePrefix("exec-and-forget"))))
    }
    return switch raw.splitArgs() {
        case .success(let args): parseCommand(args)
        case .failure(let fail): .failure(fail, EXIT_CODE_TWO)
    }
}

func parseCommand(_ args: [String]) -> ParsedCmd<any Command> {
    parseCmdArgs(args.slice).map { $0.toCommand() }
}

func expectedActualTypeError(expected: TomlType, actual: TomlType) -> String {
    "Expected type is \(expected.rawValue.singleQuoted). But actual type is \(actual.rawValue.singleQuoted)"
}

func expectedActualTypeError(expected: [TomlType], actual: TomlType) -> String {
    switch expected.singleOrNil() {
        case let single?: expectedActualTypeError(expected: single, actual: actual)
        case nil: "Expected types are \(expected.map { "'\($0)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}
