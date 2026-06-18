import AppKit
import Common
import HotKey
import TOMLDecoder
import OrderedCollections

struct ReadConfigResult {
    let configUrl: URL
    let parseConfigResult: ParseConfigResult

    @MainActor static func fatal(configUrl: URL, message: String) -> Self {
        ReadConfigResult(
            configUrl: configUrl,
            parseConfigResult: ParseConfigResult(
                config: defaultConfig,
                errors: [.init(.emptyRoot, message, preventConfigReload: true)],
                warnings: [],
            ),
        )
    }
}

@MainActor
func readConfig(forceConfigUrl: URL?) -> ReadConfigResult {
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
                return .fatal(configUrl: defaultConfigUrl, message: msg)
        }
    }
    let configStr: String
    do {
        configStr = try String(contentsOf: configUrl, encoding: .utf8)
    } catch {
        let msg = "Can't read contents of \(configUrl.path.singleQuoted) as a utf8 string: \(error.localizedDescription)"
        return .fatal(configUrl: configUrl, message: msg)
    }
    return ReadConfigResult(configUrl: configUrl, parseConfigResult: parseConfig(configStr))
}

struct ConfigParseDiagnostic: Error, Equatable {
    let backtrace: ConfigBacktrace
    let message: String
    let preventConfigReload: Bool // for severe config errors (like TOML parse error)

    public init(_ backtrace: ConfigBacktrace, _ message: String, preventConfigReload: Bool = false) {
        check(!message.isEmpty)
        self.backtrace = backtrace
        self.message = message
        self.preventConfigReload = preventConfigReload
    }

    func description(_ severity: Severity) -> String {
        let backtraceDesc = backtrace.description
        // todo Make 'split' + flatten normalization prettier
        return switch backtraceDesc.isEmpty {
            case true: "[\(severity.rawValue)] \(message)"
            case false: "[\(severity.rawValue)] \(backtraceDesc): \(message)"
        }
    }

    enum Severity: String {
        case warning = "WARNING"
        case error = "ERROR"
    }
}

typealias ParsedConfig<T> = Result<T, ConfigParseDiagnostic>

extension ParserProtocol {
    func transformRawConfig(_ raw: S,
                            _ value: OrderedJson,
                            _ backtrace: ConfigBacktrace,
                            _ errors: inout [ConfigParseDiagnostic]) -> S
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
    var parse: @Sendable (OrderedJson, ConfigBacktrace, inout [ConfigParseDiagnostic]) -> ParsedConfig<T> { get }
}

struct Parser<S: ConvenienceCopyable, T>: ParserProtocol {
    let keyPath: SendableWritableKeyPath<S, T>
    let parse: @Sendable (OrderedJson, ConfigBacktrace, inout [ConfigParseDiagnostic]) -> ParsedConfig<T>

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (OrderedJson, ConfigBacktrace, inout [ConfigParseDiagnostic]) -> T) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedConfig<T> in .success(parse(raw, backtrace, &errors)) }
    }

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (OrderedJson, ConfigBacktrace) -> ParsedConfig<T>) {
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

    "after-login-command": Parser(\._afterLoginCommand, parseDeprecatedAfterLoginCommand),
    "after-startup-command": Parser(\.afterStartupCommand) { parseCommandOrCommands($0).toParsedConfig($1) },

    "on-focus-changed": Parser(\.onFocusChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    "on-mode-changed": Parser(\.onModeChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
    "on-focused-monitor-changed": Parser(\.onFocusedMonitorChanged) { parseCommandOrCommands($0).toParsedConfig($1) },
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

extension ParsedCmd {
    func toEither() -> Parsed<T> {
        return switch self {
            case .cmd(let a): .success(a)
            case .help(let a): .failure(a)
            case .failure(let a): .failure(a.msg)
        }
    }
}

extension Command {
    fileprivate var isMacOsNativeCommand: Bool { // Problem ID-B6E178F2
        self is MacosNativeMinimizeCommand || self is MacosNativeFullscreenCommand
    }
}

func parseDeprecatedAfterLoginCommand(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<[any Command]> {
    if let array = raw.asArrayOrNil, array.count == 0 {
        return .success([])
    }
    let msg = "after-login-command is deprecated since AeroSpace 0.19.0. https://github.com/nikitabobko/AeroSpace/issues/1482"
    return .failure(.init(backtrace, msg))
}

func parseCommandOrCommands(_ raw: OrderedJson) -> Parsed<[any Command]> {
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

func tomlAnyToOrderedJsonRecursive(
    any: Any,
    _ backtrace: ConfigBacktrace,
    _ errors: inout [ConfigParseDiagnostic],
) -> OrderedJson? {
    switch any {
        case let dict as [String: Any]:
            var json = OrderedJson.JsonDict()
            for (key, tomlValue) in dict.sortedEntries {
                json[key] = tomlAnyToOrderedJsonRecursive(any: tomlValue, backtrace + .key(key), &errors)
            }
            return .dict(json)
        case let array as [Any]:
            var json = OrderedJson.JsonArray()
            for (index, tomlValue) in array.enumerated() {
                let element = tomlAnyToOrderedJsonRecursive(any: tomlValue, backtrace + .index(index), &errors)
                guard let element else { continue }
                json.append(element)
            }
            return .array(json)
        default:
            if let value = OrderedJson.newScalarOrNil(any) { return value }
            errors.append(.init(backtrace, "Unsupported TOML type: \(type(of: any))"))
            return nil
    }
}

struct ParseConfigResult {
    let config: Config
    let errors: [ConfigParseDiagnostic]
    let warnings: [ConfigParseDiagnostic]

    var allowReloadConfig: Bool { errors.allSatisfy { !$0.preventConfigReload } }
}

@MainActor func parseConfig(_ rawToml: String) -> ParseConfigResult {
    var errors: [ConfigParseDiagnostic] = []
    var warnings: [ConfigParseDiagnostic] = []

    let rawTable: OrderedJson.JsonDict
    do {
        let dict: [String: Any] = try .init(try TOMLTable(source: rawToml))
        let json = tomlAnyToOrderedJsonRecursive(any: dict, .emptyRoot, &errors)
        switch json {
            case .dict(let dict): rawTable = dict
            default: // dead code
                let msg = "Config parsing error: the top level type must be a TOML Table. But got: \((json ?? .null).tomlType)"
                errors.append(.init(.emptyRoot, msg, preventConfigReload: true))
                rawTable = [:]
        }
    } catch {
        errors.append(.init(.emptyRoot, error.description, preventConfigReload: true))
        rawTable = [:]
    }

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
            errors += [.init(.rootKey(persistentWorkspacesKey), "This config option is only available since 'config-version = 2'")]
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
            errors += [.init(
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
    if config.configVersion < maxConfigVersion {
        let msg = "The current 'config-version = \(config.configVersion)' is outdated. " +
            "Please consider migrating to 'config-version = \(maxConfigVersion)'. " +
            "See https://nikitabobko.github.io/AeroSpace/guide#config-version for the migration guide."
        warnings.append(.init(.emptyRoot, msg))
    }
    return ParseConfigResult(config: config, errors: errors, warnings: warnings)
}

func parseIndentForNestedContainersWithTheSameOrientation(_ _: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Void> {
    let msg = "Deprecated. Please drop it from the config. See https://github.com/nikitabobko/AeroSpace/issues/96"
    return .failure(.init(backtrace, msg))
}

let minConfigVersion = 1
let maxConfigVersion = 2

func parseConfigVersion(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Int> {
    parseInt(raw, backtrace)
        .filter(.init(backtrace, "config-version must be in [\(minConfigVersion), \(maxConfigVersion)] range")) { (minConfigVersion ... maxConfigVersion).contains($0) }
}

func parseInt(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Int> {
    raw.asIntOrNil.orFailure(expectedActualTypeDiagnostic(expected: .int, actual: raw.tomlType, backtrace))
}

func parseString(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<String> {
    raw.asStringOrNil.orFailure(expectedActualTypeDiagnostic(expected: .string, actual: raw.tomlType, backtrace))
}

func parseSimpleType<T>(_ raw: OrderedJson, ofType: T.Type) -> T? {
    (raw.asIntOrNil as? T) ?? (raw.asStringOrNil as? T) ?? (raw.asBoolOrNil as? T)
}

extension OrderedJson {
    func unwrapTableWithSingleKey(expectedKey: String? = nil, _ backtrace: inout ConfigBacktrace) -> ParsedConfig<(key: String, value: OrderedJson)> {
        guard let asDictOrNil else {
            return .failure(expectedActualTypeDiagnostic(expected: .table, actual: tomlType, backtrace))
        }
        let singleKeyError: ConfigParseDiagnostic = .init(
            backtrace,
            expectedKey != nil
                ? "The table is expected to have a single key '\(expectedKey.orDie())'"
                : "The table is expected to have a single key",
        )
        guard let (actualKey, value): (String, OrderedJson) = asDictOrNil.count == 1 ? asDictOrNil.first : nil else {
            return .failure(singleKeyError)
        }
        if expectedKey != nil && expectedKey != actualKey {
            return .failure(singleKeyError)
        }
        backtrace = backtrace + .key(actualKey)
        return .success((actualKey, value))
    }
}

func parseTomlArray(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<OrderedJson.JsonArray> {
    raw.asArrayOrNil.orFailure(expectedActualTypeDiagnostic(expected: .array, actual: raw.tomlType, backtrace))
}

func parseTable<T: ConvenienceCopyable>(
    _ raw: OrderedJson,
    _ initial: T,
    _ fieldsParser: [String: any ParserProtocol<T>],
    _ backtrace: ConfigBacktrace,
    _ errors: inout [ConfigParseDiagnostic],
) -> T {
    switch raw {
        case .dict(let table):
            return table.parseTable(initial, fieldsParser, backtrace, &errors)
        default:
            errors.append(expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace))
            return initial
    }
}

private func parseStartupRootContainerLayout(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Void> {
    parseString(raw, backtrace)
        .filter(.init(backtrace, "'non-empty-workspaces-root-containers-layout-on-startup' is deprecated. Please drop it from your config")) { raw in raw == "smart" }
        .map { _ in () }
}

private func parseLayout(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Layout> {
    parseString(raw, backtrace)
        .flatMap { $0.parseLayout().orFailure(.init(backtrace, "Can't parse layout '\($0)'")) }
}

private func skipParsing<T: Sendable>(_ value: T) -> @Sendable (_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<T> {
    { _, _ in .success(value) }
}

private func parsePersistentWorkspaces(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<OrderedSet<String>> {
    parseArrayOfStrings(raw, backtrace)
        .flatMap { arr in
            let set = arr.toOrderedSet()
            return set.count == arr.count ? .success(set) : .failure(.init(backtrace, "Contains duplicated workspace names"))
        }
}

private func parseArrayOfStrings(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<[String]> {
    parseTomlArray(raw, backtrace)
        .flatMap { arr in
            arr.enumerated().mapAllOrFailure { (index, elem) in
                parseString(elem, backtrace + .index(index))
            }
        }
}

private func parseDefaultContainerOrientation(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<DefaultContainerOrientation> {
    parseString(raw, backtrace).flatMap {
        DefaultContainerOrientation(rawValue: $0)
            .orFailure(.init(backtrace, "Can't parse default container orientation '\($0)'"))
    }
}

extension Parsed where Failure == String {
    func toParsedConfig(_ backtrace: ConfigBacktrace) -> ParsedConfig<Success> {
        mapError { .init(backtrace, $0) }
    }
}

func parseBool(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<Bool> {
    raw.asBoolOrNil.orFailure(expectedActualTypeDiagnostic(expected: .bool, actual: raw.tomlType, backtrace))
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

extension OrderedJson.JsonDict {
    func parseTable<T: ConvenienceCopyable>(
        _ initial: T,
        _ fieldsParser: [String: any ParserProtocol<T>],
        _ backtrace: ConfigBacktrace,
        _ errors: inout [ConfigParseDiagnostic],
    ) -> T {
        var raw = initial

        for (key, value) in self {
            let backtrace: ConfigBacktrace = backtrace + .key(key)
            switch fieldsParser[key] {
                case let parser?: raw = parser.transformRawConfig(raw, value, backtrace, &errors)
                case nil: errors.append(unknownKeyDiagnostic(backtrace))
            }
        }

        return raw
    }
}

func unknownKeyDiagnostic(_ backtrace: ConfigBacktrace) -> ConfigParseDiagnostic {
    .init(backtrace, backtrace.isRootKey ? "Unknown top-level key" : "Unknown key")
}

func expectedActualTypeDiagnostic(expected: TomlType, actual: TomlType, _ backtrace: ConfigBacktrace) -> ConfigParseDiagnostic {
    .init(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

func expectedActualTypeDiagnostic(expected: [TomlType], actual: TomlType, _ backtrace: ConfigBacktrace) -> ConfigParseDiagnostic {
    .init(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}
