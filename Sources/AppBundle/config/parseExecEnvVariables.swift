import AppKit
import Common
import TOMLKit

let testEnv = ["PATH": "AEROSPACE_TEST_PATH", "AEROSPACE_INHERITED_TEST_ENV": "inherited"]
private var env: [String: String] {
    isUnitTest ? testEnv : ProcessInfo.processInfo.environment
}

private let rawExecConfigParser: [String: any ParserProtocol<RawExecConfig>] = [
    "inherit-env-vars": Parser(\.inheritEnvVariables, parseBool),
    "env-vars": Parser(\.overriddenVars, parseEnvVariables),
]

let defaultOverriddenEnvVars = ["PATH": "/opt/homebrew/bin:/opt/homebrew/sbin:\(env["PATH"] ?? "")"]

struct ExecConfig: Equatable {
    var envVariables: [String: String] = env + defaultOverriddenEnvVars
}

struct RawExecConfig: Copyable, Equatable {
    var inheritEnvVariables = true
    // Already interpolated value of overridden vars
    var overriddenVars: [String: String] = [:]

    func expand() -> ExecConfig {
        let base: [String: String] = inheritEnvVariables ? env : [:]
        return ExecConfig(envVariables: base + overriddenVars)
    }
}

func parseExecConfig(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> ExecConfig {
    parseTable(raw, RawExecConfig(), rawExecConfigParser, backtrace, &errors).expand()
}

private func parseEnvVariables(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: String] {
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return [:]
    }
    let mutated = table.keys
    let fullEnv: [String: String] = env
    let baseEnv: [String: String] = fullEnv.filter { (key, _) -> Bool in !mutated.contains(key) }
    var result: [String: String] = [:]
    for (key, value) in table {
        let backtrace = backtrace + .key(key)
        guard let rawStr = parseString(value, backtrace).getOrNil(appendErrorTo: &errors) else { continue }
        var env = baseEnv
        if let add: String = fullEnv[key] {
            env[key] = add
        }
        let (interpolated, interpolationErrors) = rawStr.interpolate(with: env)
        errors += interpolationErrors.map { .semantic(backtrace, $0) }
        result[key] = interpolated
    }
    return result
}
