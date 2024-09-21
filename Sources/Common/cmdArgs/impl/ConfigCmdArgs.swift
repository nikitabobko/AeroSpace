public struct ConfigCmdArgs: CmdArgs, Equatable {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .config,
        allowInConfig: false,
        help: config_help_generated,
        options: [
            "--json": trueBoolFlag(\.json),
            "--keys": trueBoolFlag(\.keys),
            "--major-keys": trueBoolFlag(\.majorKeys),
            "--all-keys": trueBoolFlag(\.allKeys),
            "--config-path": trueBoolFlag(\.configPath),
            "--get": singleValueOption(\.keyNameToGet, "<name>") { $0 },
        ],
        arguments: []
    )

    public var json: Bool = false
    public var majorKeys: Bool = false
    public var keys: Bool = false
    public var allKeys: Bool = false
    public var configPath: Bool = false
    public var keyNameToGet: String? = nil
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}

public extension ConfigCmdArgs {
    enum Mode {
        case getKey(key: String), majorKeys, allKeys, configPath
    }

    var mode: Mode {
        if let keyNameToGet { return .getKey(key: keyNameToGet) }
        if majorKeys { return .majorKeys }
        if allKeys { return .allKeys }
        if configPath { return .configPath }
        error("At least one mode must be specified")
    }
}

public func parseConfigCmdArgs(_ args: [String]) -> ParsedCmd<ConfigCmdArgs> {
    parseSpecificCmdArgs(ConfigCmdArgs(rawArgs: .init(args)), args)
        .flatMap { raw in
            var conflicting: Set<String> = []
            if raw.keyNameToGet != nil { conflicting.insert("--get") }
            if raw.majorKeys { conflicting.insert("--major-keys") }
            if raw.allKeys { conflicting.insert("--all-keys") }
            if raw.configPath { conflicting.insert("--config-path") }
            return switch conflicting.count {
                case 1: .cmd(raw)
                case 0: .failure("Mandatory flag is not specified (--get|--major-keys|--all-keys|--config-path)")
                default: .failure("Conflicting flags are specified: \(conflicting.joined(separator: ", "))")
            }
        }
        .filter("--keys flag requires --get flag") { !$0.keys || $0.keyNameToGet != nil }
        .filter("--json flag requires --get flag") { !$0.json || $0.keyNameToGet != nil }
}
