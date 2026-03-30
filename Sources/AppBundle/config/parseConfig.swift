import AppKit
import Common
import HotKey
import TOMLDecoder
import OrderedCollections

@MainActor
func readConfig(forceConfigUrl: URL? = nil) -> Result<(Config, URL), String> {
    let configUrl: URL
    if let forceConfigUrl {
        configUrl = forceConfigUrl
    } else {
        switch findCustomConfigUrl() {
            case .file(let url): configUrl = url
            case .noCustomConfigExists: configUrl = defaultConfigUrl
            case .ambiguousConfigError(let candidates):
                let msg = """
                    Ambiguous config error. Several configs found:
                    \(candidates.map(\.path).joined(separator: "\n"))
                    """
                return .failure(msg)
        }
    }
    let (parsedConfig, errors) = (try? String(contentsOf: configUrl, encoding: .utf8)).map { parseConfig($0) } ?? (defaultConfig, [])

    if errors.isEmpty {
        return .success((parsedConfig, configUrl))
    } else {
        let msg = """
            Failed to parse \(configUrl.absoluteURL.path)

            \(errors.map(\.description).joined(separator: "\n\n"))
            """
        return .failure(msg)
    }
}

enum ConfigParseError: Error, CustomStringConvertible, Equatable {
    case semantic(_ backtrace: ConfigBacktrace, _ message: String)
    case syntax(_ message: String)

    var description: String {
        return switch self {
            // todo Make 'split' + flatten normalization prettier
            case .semantic(let backtrace, let message) where backtrace.description.isEmpty: message
            case .semantic(let backtrace, let message): "\(backtrace): \(message)"
            case .syntax(let message): message
        }
    }
}

typealias ParsedConfig<T> = Result<T, ConfigParseError>

extension ParserProtocol {
    func transformRawConfig(_ raw: S,
                            _ value: Json,
                            _ backtrace: ConfigBacktrace,
                            _ errors: inout [ConfigParseError]) -> S
    {
        if let value = parse(value, backtrace, &errors).getOrNil(appendErrorTo: &errors) {
            return raw.copy(keyPath, value)
        }
        return raw
    }
}

protocol ParserProtocol<S>: Sendable {
    associatedtype T
    associatedtype S where S: ConvenienceCopyable
    var keyPath: SendableWritableKeyPath<S, T> { get }
    var parse: @Sendable (Json, ConfigBacktrace, inout [ConfigParseError]) -> ParsedConfig<T> { get }
}

struct Parser<S: ConvenienceCopyable, T>: ParserProtocol {
    let keyPath: SendableWritableKeyPath<S, T>
    let parse: @Sendable (Json, ConfigBacktrace, inout [ConfigParseError]) -> ParsedConfig<T>

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (Json, ConfigBacktrace, inout [ConfigParseError]) -> T) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedConfig<T> in .success(parse(raw, backtrace, &errors)) }
    }

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (Json, ConfigBacktrace) -> ParsedConfig<T>) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, _ -> ParsedConfig<T> in parse(raw, backtrace) }
    }
}

private let keyMappingConfigRootKey = "key-mapping"
private let modeConfigRootKey = "mode"
private let persistentWorkspacesKey = "persistent-workspaces"

// For every new config option you add, think:
// 1. Does it make sense to have different value
// 2. Prefer commands and commands flags over toml options if possible
private let configParser: [String: any ParserProtocol<Config>] = [
    "config-version": Parser(\.configVersion, parseConfigVersion),

    "after-login-command": Parser(\.afterLoginCommand, parseAfterLoginCommand),
    "after-startup-command": Parser(\.afterStartupCommand) { parseCommandOrCommands($0).toParsedConfig($1) },

    "on-focus-changed": Parser(\.onFocusChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    "on-mode-changed": Parser(\.onModeChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    "on-focused-monitor-changed": Parser(\.onFocusedMonitorChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    "on-monitor-changed": Parser(\.onMonitorChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    // "on-focused-workspace-changed": Parser(\.onFocusedWorkspaceChanged, { parseCommandOrCommands($0).toParsedConfig($1) }),

    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, parseBool),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, parseBool),

    "default-root-container-layout": Parser(\.defaultRootContainerLayout, parseLayout),
    "default-root-container-orientation": Parser(\.defaultRootContainerOrientation, parseDefaultContainerOrientation),

    "start-at-login": Parser(\.startAtLogin, parseBool),
    "auto-reload-config": Parser(\.autoReloadConfig, parseBool),
    "automatically-unhide-macos-hidden-apps": Parser(\.automaticallyUnhideMacosHiddenApps, parseBool),
    "accordion-padding": Parser(\.accordionPadding, parseInt),
    persistentWorkspacesKey: Parser(\.persistentWorkspaces, parsePersistentWorkspaces),
    "exec-on-workspace-change": Parser(\.execOnWorkspaceChange, parseArrayOfStrings),
    "exec": Parser(\.execConfig, parseExecConfig),

    keyMappingConfigRootKey: Parser(\.keyMapping, skipParsing(Config().keyMapping)), // Parsed manually
    modeConfigRootKey: Parser(\.modes, skipParsing(Config().modes)), // Parsed manually

    "gaps": Parser(\.gaps, parseGaps),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, parseWorkspaceToMonitorAssignment),
    "on-window-detected": Parser(\.onWindowDetected, parseOnWindowDetectedArray),

    // Deprecated
    "non-empty-workspaces-root-containers-layout-on-startup": Parser(\._nonEmptyWorkspacesRootContainersLayoutOnStartup, parseStartupRootContainerLayout),
    "indent-for-nested-containers-with-the-same-orientation": Parser(\._indentForNestedContainersWithTheSameOrientation, parseIndentForNestedContainersWithTheSameOrientation),
]

extension ParsedCmd where T == any Command {
    fileprivate func toEither() -> Parsed<T> {
        return switch self {
            case .cmd(let a):
                a.info.allowInConfig
                    ? .success(a)
                    : .failure("Command '\(a.info.kind.rawValue)' cannot be used in config")
            case .help(let a): .failure(a)
            case .failure(let a): .failure(a)
        }
    }
}

extension Command {
    fileprivate var isMacOsNativeCommand: Bool { // Problem ID-B6E178F2
        self is MacosNativeMinimizeCommand || self is MacosNativeFullscreenCommand
    }
}

func parseAfterLoginCommand(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<[any Command]> {
    if let array = raw.asArrayOrNil, array.count == 0 {
        return .success([])
    }
    let msg = "after-login-command is deprecated since AeroSpace 0.19.0. https://github.com/nikitabobko/AeroSpace/issues/1482"
    return .failure(.semantic(backtrace, msg))
}

func parseCommandOrCommands(_ raw: Json) -> Parsed<[any Command]> {
    if let rawString = raw.asStringOrNil {
        return parseCommand(rawString).toEither().map { [$0] }
    } else if let rawArray = raw.asArrayOrNil {
        let commands: Parsed<[any Command]> = (0 ..< rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].asStringOrNil ?? expectedActualTypeError(expected: .string, actual: rawArray[index].tomlType)
            return parseCommand(rawString).toEither()
        }
        return commands.filter("macos-native-* commands are only allowed to be the last commands in the list") {
            !$0.dropLast().contains(where: { $0.isMacOsNativeCommand })
        }
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.tomlType))
    }
}

func tomlAnyToParsedConfigRecursive(any: Any, _ backtrace: ConfigBacktrace) -> ParsedConfig<Json> {
    switch any {
        case let dict as [String: Any]:
            var json = Json.JsonDict()
            for (key, tomlValue) in dict {
                let jsonResultValue = tomlAnyToParsedConfigRecursive(any: tomlValue, backtrace + .key(key))
                switch jsonResultValue {
                    case .success(let jsonValue): json[key] = jsonValue
                    case .failure(let fail): return .failure(fail)
                }
            }
            return .success(.dict(json))
        case let array as [Any]:
            var json = Json.JsonArray()
            for (index, tomlValue) in array.enumerated() {
                let jsonResultValue = tomlAnyToParsedConfigRecursive(any: tomlValue, backtrace + .index(index))
                switch jsonResultValue {
                    case .success(let jsonValue): json.append(jsonValue)
                    case .failure(let fail): return .failure(fail)
                }
            }
            return .success(.array(json))
        default:
            return Json.newScalarOrNil(any).map(Result.success)
                ?? .failure(.semantic(backtrace, "Unsupported TOML type: \(type(of: any))"))
    }
}

@MainActor func parseConfig(_ rawToml: String) -> (config: Config, errors: [String]) { // todo change return value to Result
    let result = _parseConfig(rawToml)
    return (result.config, result.errors.map(\.description).sorted())
}

@MainActor private func _parseConfig(_ rawToml: String) -> (config: Config, errors: [ConfigParseError]) { // todo change return value to Result
    let rawTable: Json.JsonDict
    do {
        let dict: [String: Any] = try .init(try TOMLTable(source: rawToml))
        switch tomlAnyToParsedConfigRecursive(any: dict, .emptyRoot) {
            case .success(.dict(let dict)): rawTable = dict
            case .success: return (defaultConfig, [.syntax("Config parsing error: the top level type must be a TOML Table")])
            case .failure(let fail): return (defaultConfig, [fail])
        }
    } catch {
        return (defaultConfig, [.syntax(error.description)])
    }

    var errors: [ConfigParseError] = []

    var config = rawTable.parseTable(Config(), configParser, .emptyRoot, &errors)

    if let mapping = rawTable[keyMappingConfigRootKey].flatMap({ parseKeyMapping($0, .rootKey(keyMappingConfigRootKey), &errors) }) {
        config.keyMapping = mapping
    }

    // Parse modeConfigRootKey after keyMappingConfigRootKey
    if let modes = rawTable[modeConfigRootKey].flatMap({ parseModes($0, .rootKey(modeConfigRootKey), &errors, config.keyMapping.resolve()) }) {
        config.modes = modes
    }

    if config.configVersion <= 1 {
        if rawTable.keys.contains(persistentWorkspacesKey) {
            errors += [.semantic(.rootKey(persistentWorkspacesKey), "This config option is only available since 'config-version = 2'")]
        }
        config.persistentWorkspaces = (config.modes.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in Array(mode.bindings.values) }
            .flatMap { (binding: HotkeyBinding) -> [String] in
                binding.commands.filterIsInstance(of: WorkspaceCommand.self).compactMap { $0.args.target.val.workspaceNameOrNil()?.raw } +
                    binding.commands.filterIsInstance(of: MoveNodeToWorkspaceCommand.self).compactMap { $0.args.target.val.workspaceNameOrNil()?.raw }
            }
            + (config.workspaceToMonitorForceAssignment).keys)
            .toOrderedSet()
    }

    if config.enableNormalizationFlattenContainers {
        let containsSplitCommand = config.modes.values.lazy.flatMap { $0.bindings.values }
            .flatMap { $0.commands }
            .contains { $0 is SplitCommand }
        if containsSplitCommand {
            errors += [.semantic(
                .emptyRoot, // todo Make 'split' + flatten normalization prettier
                """
                The config contains:
                1. usage of 'split' command
                2. enable-normalization-flatten-containers = true
                These two settings don't play nicely together. 'split' command has no effect when enable-normalization-flatten-containers is disabled.

                My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.
                """,
            )]
        }
    }
    return (config, errors)
}

func parseIndentForNestedContainersWithTheSameOrientation(_ _: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Void> {
    let msg = "Deprecated. Please drop it from the config. See https://github.com/nikitabobko/AeroSpace/issues/96"
    return .failure(.semantic(backtrace, msg))
}

func parseConfigVersion(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Int> {
    let min = 1
    let max = 2
    return parseInt(raw, backtrace)
        .filter(.semantic(backtrace, "Must be in [\(min), \(max)] range")) { (min ... max).contains($0) }
}

func parseInt(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Int> {
    raw.asIntOrNil.orFailure(expectedActualTypeError(expected: .int, actual: raw.tomlType, backtrace))
}

func parseString(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<String> {
    raw.asStringOrNil.orFailure(expectedActualTypeError(expected: .string, actual: raw.tomlType, backtrace))
}

func parseSimpleType<T>(_ raw: Json, ofType: T.Type) -> T? {
    (raw.asIntOrNil as? T) ?? (raw.asStringOrNil as? T) ?? (raw.asBoolOrNil as? T)
}

extension Json {
    func unwrapTableWithSingleKey(expectedKey: String? = nil, _ backtrace: inout ConfigBacktrace) -> ParsedConfig<(key: String, value: Json)> {
        guard let asDictOrNil else {
            return .failure(expectedActualTypeError(expected: .table, actual: tomlType, backtrace))
        }
        let singleKeyError: ConfigParseError = .semantic(
            backtrace,
            expectedKey != nil
                ? "The table is expected to have a single key '\(expectedKey.orDie())'"
                : "The table is expected to have a single key",
        )
        guard let (actualKey, value): (String, Json) = asDictOrNil.count == 1 ? asDictOrNil.first : nil else {
            return .failure(singleKeyError)
        }
        if expectedKey != nil && expectedKey != actualKey {
            return .failure(singleKeyError)
        }
        backtrace = backtrace + .key(actualKey)
        return .success((actualKey, value))
    }
}

func parseTomlArray(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Json.JsonArray> {
    raw.asArrayOrNil.orFailure(expectedActualTypeError(expected: .array, actual: raw.tomlType, backtrace))
}

func parseTable<T: ConvenienceCopyable>(
    _ raw: Json,
    _ initial: T,
    _ fieldsParser: [String: any ParserProtocol<T>],
    _ backtrace: ConfigBacktrace,
    _ errors: inout [ConfigParseError],
) -> T {
    guard let table = raw.asDictOrNil else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace))
        return initial
    }
    return table.parseTable(initial, fieldsParser, backtrace, &errors)
}

private func parseStartupRootContainerLayout(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Void> {
    parseString(raw, backtrace)
        .filter(.semantic(backtrace, "'non-empty-workspaces-root-containers-layout-on-startup' is deprecated. Please drop it from your config")) { raw in raw == "smart" }
        .map { _ in () }
}

private func parseLayout(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Layout> {
    parseString(raw, backtrace)
        .flatMap { $0.parseLayout().orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
}

private func skipParsing<T: Sendable>(_ value: T) -> @Sendable (_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<T> {
    { _, _ in .success(value) }
}

private func parsePersistentWorkspaces(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<OrderedSet<String>> {
    parseArrayOfStrings(raw, backtrace)
        .flatMap { arr in
            let set = arr.toOrderedSet()
            return set.count == arr.count ? .success(set) : .failure(.semantic(backtrace, "Contains duplicated workspace names"))
        }
}

private func parseArrayOfStrings(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<[String]> {
    parseTomlArray(raw, backtrace)
        .flatMap { arr in
            arr.enumerated().mapAllOrFailure { (index, elem) in
                parseString(elem, backtrace + .index(index))
            }
        }
}

private func parseDefaultContainerOrientation(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<DefaultContainerOrientation> {
    parseString(raw, backtrace).flatMap {
        DefaultContainerOrientation(rawValue: $0)
            .orFailure(.semantic(backtrace, "Can't parse default container orientation '\($0)'"))
    }
}

extension Parsed where Failure == String {
    func toParsedConfig(_ backtrace: ConfigBacktrace) -> ParsedConfig<Success> {
        mapError { .semantic(backtrace, $0) }
    }
}

func parseBool(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Bool> {
    raw.asBoolOrNil.orFailure(expectedActualTypeError(expected: .bool, actual: raw.tomlType, backtrace))
}

struct ConfigBacktrace: CustomStringConvertible, Equatable {
    private var path: [TomlBacktraceItem] = []
    private init(_ path: [TomlBacktraceItem]) {
        check(path.first?.isKey != false, "Tried to construct invalid TOML path: \(path)")
        self.path = path
    }

    static func rootKey(_ key: String) -> Self { .init([.key(key)]) }
    static let emptyRoot: Self = .init([])

    var description: String {
        var result = ""
        for (i, elem) in path.enumerated() {
            switch elem {
                case .key(let rootKey) where i == 0: result += rootKey
                case .key(let key): result += ".\(key)"
                case .index(let index): result += "[\(index)]"
            }
        }
        return result
    }

    var isRootKey: Bool { path.singleOrNil().map(\.isKey) == true }

    static func + (lhs: Self, rhs: TomlBacktraceItem) -> Self {
        var result = lhs
        result.path += [rhs]
        return result
    }
}

enum TomlBacktraceItem: Equatable {
    case key(String)
    case index(Int)

    var isKey: Bool {
        switch self {
            case .key: true
            case .index: false
        }
    }
}

extension Json.JsonDict {
    func parseTable<T: ConvenienceCopyable>(
        _ initial: T,
        _ fieldsParser: [String: any ParserProtocol<T>],
        _ backtrace: ConfigBacktrace,
        _ errors: inout [ConfigParseError],
    ) -> T {
        var raw = initial

        for (key, value) in self {
            let backtrace: ConfigBacktrace = backtrace + .key(key)
            if let parser = fieldsParser[key] {
                raw = parser.transformRawConfig(raw, value, backtrace, &errors)
            } else {
                errors.append(unknownKeyError(backtrace))
            }
        }

        return raw
    }
}

func unknownKeyError(_ backtrace: ConfigBacktrace) -> ConfigParseError {
    .semantic(backtrace, backtrace.isRootKey ? "Unknown top-level key" : "Unknown key")
}

func expectedActualTypeError(expected: TomlType, actual: TomlType, _ backtrace: ConfigBacktrace) -> ConfigParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

func expectedActualTypeError(expected: [TomlType], actual: TomlType, _ backtrace: ConfigBacktrace) -> ConfigParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}
