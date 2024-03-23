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
    let baseEnv: [String: String] = fullEnv.filter { (key, value) -> Bool in !mutated.contains(key) }
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

extension String {
    func interpolate(with variables: [String: String]) -> (result: String, errors: [String]) {
        var mode: InterpolationParserState = .stringLiteral
        var result = ""
        var errors: [String] = []
        for char: Character? in (Array(self) + [nil]) {
            switch (mode, char) { // State machine
            case (.stringLiteral, "$"):
                mode = .dollarEncountered
            case (.stringLiteral, _):
                if let char {
                    result.append(char)
                }
            case (.dollarEncountered, "{"):
                mode = .interpolatedValue("")
            case (.dollarEncountered, "$"):
                result.append("$")
            case (.dollarEncountered, _):
                result.append("$")
                if let char {
                    result.append(char)
                }
                mode = .stringLiteral
            case (.interpolatedValue(let value), "}"):
                if let expanded = variables[value] {
                    result.append(expanded)
                } else {
                    errors.append("Env variable '\(value)' isn't presented in AeroSpace.app Env vars, or not available for interpolation (because it's mutated)")
                }
                mode = .stringLiteral
            case (.interpolatedValue(let value), "{"):
                return ("", ["Can't parse '\(value + "{")' environment variable (Open curly brace is invalid character)"])
            case (.interpolatedValue(let value), "$"):
                return ("", ["Can't parse '\(value + "$")' environment variable (Dollar is invalid character)"])
            case (.interpolatedValue(let value), _):
                if let char {
                    mode = .interpolatedValue(value + String(char))
                } else {
                    return ("", ["Unbalanced curly braces"])
                }
            }
        }
        return (result, errors)
    }
}

private enum InterpolationParserState {
    case stringLiteral, dollarEncountered
    case interpolatedValue(String)
}
