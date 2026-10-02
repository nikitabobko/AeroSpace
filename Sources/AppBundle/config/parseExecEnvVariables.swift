import AppKit
import Common

let testEnv = ["PATH": "AEROSPACE_TEST_PATH", "AEROSPACE_INHERITED_TEST_ENV": "inherited"]
private var env: [String: String] {
    isUnitTest ? testEnv : ProcessInfo.processInfo.environment
}

private let rawExecConfigParser: [String: any ParserProtocol<RawExecConfig>] = [
    "inherit-env-vars": Parser(\.inheritEnvVariables, parseBool),
    "env-vars": Parser(\.overriddenVars, parseEnvVariables),
]

let defaultOverriddenEnvVars = ["PATH": getDefaultExecPath(isIntelMac: isIntelMac, inheritedPath: env["PATH"] ?? "")]

// GUI apps on macOS don't have Homebrew's prefix in their PATH https://docs.brew.sh/FAQ#my-mac-apps-dont-find-homebrew-utilities
// Homebrew's prefix is /opt/homebrew on Apple Silicon and /usr/local on Intel https://docs.brew.sh/Installation
func getDefaultExecPath(isIntelMac: Bool, inheritedPath: String) -> String {
    (isIntelMac ? "/usr/local/bin:/usr/local/sbin:" : "") + "/opt/homebrew/bin:/opt/homebrew/sbin:\(inheritedPath)"
}

// "hw.optional.arm64" is 1 on Apple Silicon (even under Rosetta), and it's absent on Intel
let isIntelMac: Bool = {
    var isArm64: Int32 = 0
    var size = MemoryLayout<Int32>.size
    return unsafe sysctlbyname("hw.optional.arm64", &isArm64, &size, nil, 0) != 0 || isArm64 == 0
}()

struct ExecConfig: Equatable {
    var envVariables: [String: String] = env + defaultOverriddenEnvVars
}

struct RawExecConfig: ConvenienceMutable, Equatable {
    var inheritEnvVariables = true
    // Already interpolated value of overridden vars
    var overriddenVars: [String: String] = [:]

    func expand() -> ExecConfig {
        let base: [String: String] = inheritEnvVariables ? env : [:]
        return ExecConfig(envVariables: base + overriddenVars)
    }
}

func parseExecConfig(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> ExecConfig {
    parseTable(raw, RawExecConfig(), rawExecConfigParser, backtrace, &c).expand()
}

private func parseEnvVariables(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: String] {
    guard let table = raw.asDictOrNil else {
        c.errors.append(expectedActualTypeDiagnostic(expected: .array, actual: raw.tomlType, backtrace))
        return [:]
    }
    let mutated = table.keys
    let fullEnv: [String: String] = env
    let baseEnv: [String: String] = fullEnv.filter { (key, _) -> Bool in !mutated.contains(key) }
    var result: [String: String] = [:]
    for (key, value) in table {
        let backtrace = backtrace + .key(key)
        if key == "PWD" { c.errors.append(.init(backtrace, "Changing 'PWD' is not allowed")) }
        guard let rawStr = parseString(value, backtrace).getOrNil(appendErrorTo: &c.errors) else { continue }
        var env = baseEnv
        if let add: String = fullEnv[key] {
            env[key] = add
        }
        switch rawStr.interpolate(with: env) {
            case .success(let interpolated): result[key] = interpolated
            case .failure(let _errros): c.errors += _errros.map { .init(backtrace, $0) }
        }
    }
    return result
}
