import Common
import AppKit
import HotKey
import TOMLKit

func reloadConfig() {
    resetHotKeys()
    let configUrl: URL?
    switch getConfigFileUrl() {
        case .file(let url):
            configUrl = url
        case .ambiguousConfigError(let candidates):
            showAmbiguousConfigErrorToUser(candidates)
            configUrl = nil
        case .noCustomConfigExists:
            configUrl = nil
    }
    let (parsedConfig, errors) = configUrl.flatMap { try? String(contentsOf: $0) }.map { parseConfig($0) }
        ?? (defaultConfig, [])

    if errors.isEmpty {
        config = parsedConfig
    } else {
        showConfigParsingErrorsToUser(errors, configUrl: configUrl)
    }
    activateMode(mainModeId)
    syncStartAtLogin()
}

let configDotfileName = isDebug ? ".aerospace-debug.toml" : ".aerospace.toml"
func getConfigFileUrl() -> ConfigFile {
    let fileName = isDebug ? "aerospace-debug.toml" : "aerospace.toml"
    let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]?.lets { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/")
    let candidates = [
        FileManager.default.homeDirectoryForCurrentUser.appending(path: configDotfileName),
        xdgConfigHome.appending(path: "aerospace").appending(path: fileName),
    ]
    let existingCandidates: [URL] = candidates.filter { (candidate: URL) in FileManager.default.fileExists(atPath: candidate.path) }
    let count = existingCandidates.count
    if count == 1 {
        return .file(existingCandidates.first!)
    } else if count > 1 {
        return .ambiguousConfigError(existingCandidates)
    } else {
        return .noCustomConfigExists
    }
}

enum ConfigFile {
    case file(URL), ambiguousConfigError(_ candidates: [URL]), noCustomConfigExists

    var urlOrNil: URL? {
        return switch self {
            case .file(let url): url
            case .ambiguousConfigError, .noCustomConfigExists: nil
        }
    }
}

private func showAmbiguousConfigErrorToUser(_ candidates: [URL]) {
    let message =
        """
        #################################################
        ### AEROSPACE AMBIGUOUS CONFIG LOCATION ERROR ###
        #################################################

        Several configs are found:
        \(candidates.map(\.path).joined(separator: "\n"))

        Fallback to default config
        """
    showMessageToUser(filename: "ambiguous-config-error.txt", message: message)
}

private func showConfigParsingErrorsToUser(_ errors: [TomlParseError], configUrl: URL?) {
    let message =
        """
        ####################################
        ### AEROSPACE CONFIG PARSE ERROR ###
        ####################################

        Failed to parse \(configUrl?.absoluteURL.path ?? "nil")

        \(errors.map(\.description).joined(separator: "\n\n"))
        """
    showMessageToUser(filename: "config-parse-error.txt", message: message)
}

enum TomlParseError: Error, CustomStringConvertible {
    case semantic(_ backtrace: TomlBacktrace, _ message: String)
    case syntax(_ message: String)

    var description: String {
        switch self {
        case .semantic(let backtrace, let message):
            if case .root = backtrace { // todo Make 'split' + flatten normalization prettier
                return message
            } else {
                return "\(backtrace): \(message)"
            }
        case .syntax(let message):
            return message
        }
    }
}

typealias ParsedToml<T> = Result<T, TomlParseError>

extension ParserProtocol {
    func transformRawConfig(_ raw: S,
                            _ value: TOMLValueConvertible,
                            _ backtrace: TomlBacktrace,
                            _ errors: inout [TomlParseError]) -> S {
        if let value = parse(value, backtrace, &errors).getOrNil(appendErrorTo: &errors) {
            return raw.copy(keyPath, value)
        }
        return raw
    }
}

protocol ParserProtocol<S> {
    associatedtype T
    associatedtype S where S: Copyable
    var keyPath: WritableKeyPath<S, T> { get }
    var parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T> { get }
}

struct Parser<S: Copyable, T>: ParserProtocol {
    let keyPath: WritableKeyPath<S, T>
    let parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T>

    init(_ keyPath: WritableKeyPath<S, T>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> T) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedToml<T> in .success(parse(raw, backtrace, &errors)) }
    }

    init(_ keyPath: WritableKeyPath<S, T>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, _ -> ParsedToml<T> in parse(raw, backtrace) }
    }
}

private let keyMappingConfigRootKey = "key-mapping"
private let modeConfigRootKey = "mode"

private let configParser: [String: any ParserProtocol<Config>] = [
    "after-login-command": Parser(\.afterLoginCommand, { parseCommandOrCommands($0).toParsedToml($1) }),
    "after-startup-command": Parser(\.afterStartupCommand, { parseCommandOrCommands($0).toParsedToml($1) }),

    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, parseBool),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, parseBool),

    "non-empty-workspaces-root-containers-layout-on-startup": Parser(\._nonEmptyWorkspacesRootContainersLayoutOnStartup, parseStartupRootContainerLayout),

    "default-root-container-layout": Parser(\.defaultRootContainerLayout, parseLayout),
    "default-root-container-orientation": Parser(\.defaultRootContainerOrientation, parseDefaultContainerOrientation),

    "indent-for-nested-containers-with-the-same-orientation": Parser(\.indentForNestedContainersWithTheSameOrientation, parseInt),
    "start-at-login": Parser(\.startAtLogin, parseBool),
    "accordion-padding": Parser(\.accordionPadding, parseInt),
    "exec-on-workspace-change": Parser(\.execOnWorkspaceChange, parseExecOnWorkspaceChange),
    "exec": Parser(\.execConfig, parseExecConfig),

    keyMappingConfigRootKey: Parser(\.keyMapping, skipParsing(Config().keyMapping)), // Parsed manually
    modeConfigRootKey: Parser(\.modes, skipParsing(Config().modes)), // Parsed manually

    "gaps": Parser(\.gaps, parseGaps),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, parseWorkspaceToMonitorAssignment),
    "on-window-detected": Parser(\.onWindowDetected, parseOnWindowDetectedArray)
]

private extension ParsedCmd where T == any Command {
    func toEither() -> Parsed<T> {
        switch self {
        case .cmd(let a):
            return a.info.allowInConfig
                ? .success(a)
                : .failure("Command '\(a.info.kind.rawValue)' cannot be used in config")
        case .help(let a):
            return .failure(a)
        case .failure(let a):
            return .failure(a)
        }
    }
}

private extension Command {
    var isMacOsNativeCommand: Bool { // Problem ID-B6E178F2
        self is MacosNativeMinimizeCommand || self is MacosNativeFullscreenCommand
    }
}

func parseCommandOrCommands(_ raw: TOMLValueConvertible) -> Parsed<[any Command]> {
    if let rawString = raw.string {
        return parseCommand(rawString).toEither().map { [$0] }
    } else if let rawArray = raw.array {
        let commands: Parsed<[any Command]> = (0..<rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].string ?? expectedActualTypeError(expected: .string, actual: rawArray[index].type)
            return parseCommand(rawString).toEither()
        }
        return commands.filter("macos-native-* commands are only allowed to be the last commands in the list") {
            !$0.dropLast().contains(where: { $0.isMacOsNativeCommand })
        }
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.type))
    }
}

func parseConfig(_ rawToml: String) -> (config: Config, errors: [TomlParseError]) {
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        return (defaultConfig, [.syntax(e.debugDescription)])
    } catch let e {
        return (defaultConfig, [.syntax(e.localizedDescription)])
    }

    var errors: [TomlParseError] = []

    var config = rawTable.parseTable(Config(), configParser, .root, &errors)

    if let mapping = rawTable[keyMappingConfigRootKey].flatMap({ parseKeyMapping($0, .rootKey(keyMappingConfigRootKey), &errors) }) {
        config.keyMapping = mapping
    }

    if let modes = rawTable[modeConfigRootKey].flatMap({ parseModes($0, .rootKey(modeConfigRootKey), &errors, config.keyMapping.resolve()) }) {
        config.modes = modes
    }

    config.preservedWorkspaceNames = config.modes.values.lazy
        .flatMap { (mode: Mode) -> [HotkeyBinding] in Array(mode.bindings.values) }
        .flatMap { (binding: HotkeyBinding) -> [String] in
            binding.commands.filterIsInstance(of: WorkspaceCommand.self).compactMap { $0.args.target.workspaceNameOrNil()?.raw } +
                binding.commands.filterIsInstance(of: MoveNodeToWorkspaceCommand.self).compactMap { $0.args.target.workspaceNameOrNil()?.raw }
        }
        + (config.workspaceToMonitorForceAssignment).keys

    if config.enableNormalizationFlattenContainers {
        let containsSplitCommand = config.modes.values.lazy.flatMap { $0.bindings.values }
            .flatMap { $0.commands }
            .contains { $0 is SplitCommand }
        if containsSplitCommand {
            errors += [.semantic(.root, // todo Make 'split' + flatten normalization prettier
                """
                The config contains:
                1. usage of 'split' command
                2. enable-normalization-flatten-containers = true
                These two settings don't play nicely together. 'split' command has no effect in this case
                """
            )]
        }
    }
    return (config, errors)
}

func parseInt(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    raw.int.orFailure(expectedActualTypeError(expected: .int, actual: raw.type, backtrace))
}

func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    raw.string.orFailure(expectedActualTypeError(expected: .string, actual: raw.type, backtrace))
}

func parseSimpleType<T>(_ raw: TOMLValueConvertible) -> T? {
    (raw.int as? T) ?? (raw.string as? T) ?? (raw.bool as? T)
}

func parseDynamicValue<T>(
    _ raw: TOMLValueConvertible,
    _ valueType: T.Type,
    _ fallback: T,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> DynamicConfigValue<T> {
    if let simpleValue = parseSimpleType(raw) as T? {
        return .constant(simpleValue)
    } else if let array = raw.array {
        if array.isEmpty {
            errors.append(.semantic(backtrace, "The array must not be empty"))
            return .constant(fallback)
        }

        guard let defaultValue = array.last.flatMap({ parseSimpleType($0) as T? }) else {
            errors.append(.semantic(backtrace, "The last item in the array must be of type \(T.self)"))
            return .constant(fallback)
        }

        if array.dropLast().isEmpty {
            errors.append(.semantic(backtrace, "The array must contain at least one monitor pattern"))
            return .constant(fallback)
        }

        let rules: [PerMonitorValue<T>] = parsePerMonitorValues(TOMLArray(array.dropLast()), backtrace, &errors)

        return .perMonitor(rules, default: defaultValue)
    } else {
        errors.append(.semantic(backtrace, "Unsupported type: \(raw.type), expected: \(valueType) or array"))
        return .constant(fallback)
    }
}

func parsePerMonitorValues<T>(_ array: TOMLArray, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [PerMonitorValue<T>] {
    array.enumerated().compactMap { (index: Int, raw: TOMLValueConvertible) -> PerMonitorValue<T>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors) else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(key, backtrace)

        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        guard let value = parseSimpleType(value) as T? else {
            errors.append(.semantic(backtrace, "Expected type is '\(T.self)'. But actual type is '\(value.type)'"))
            return nil
        }

        return (description: monitorDescription, value: value) as PerMonitorValue<T>
    }
}

private extension TOMLValueConvertible {
    func unwrapTableWithSingleKey(expectedKey: String? = nil, _ backtrace: inout TomlBacktrace) -> ParsedToml<(key: String, value: TOMLValueConvertible)> {
        guard let table = table else {
            return .failure(expectedActualTypeError(expected: .table, actual: type, backtrace))
        }
        let singleKeyError: TomlParseError = .semantic(backtrace,
            expectedKey != nil
                ? "The table is expected to have a single key '\(expectedKey!)'"
                : "The table is expected to have a single key"
        )
        guard let (actualKey, value): (String, TOMLValueConvertible) = table.count == 1 ? table.first : nil else {
            return .failure(singleKeyError)
        }
        if expectedKey != nil && expectedKey != actualKey {
            return .failure(singleKeyError)
        }
        backtrace = backtrace + .key(actualKey)
        return .success((actualKey, value))
    }
}

func parseTomlArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<TOMLArray> {
    raw.array.orFailure(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
}

func parseTable<T: Copyable>(
    _ raw: TOMLValueConvertible,
    _ initial: T,
    _ fieldsParser: [String: any ParserProtocol<T>],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> T {
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return initial
    }
    return table.parseTable(initial, fieldsParser, backtrace, &errors)
}

private func parseStartupRootContainerLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Void> {
    parseString(raw, backtrace)
        .filter(.semantic(backtrace, "'non-empty-workspaces-root-containers-layout-on-startup' is deprecated. Please drop it from your config")) { raw in raw == "smart" }
        .map { _ in () }
}

private func parseLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Layout> {
    parseString(raw, backtrace)
        .flatMap { $0.parseLayout().orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
}

private func skipParsing<T>(_ value: T) -> (_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<T> {
    { _, _ in .success(value) }
}

private func parseExecOnWorkspaceChange(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<[String]> {
    parseTomlArray(raw, backtrace)
        .flatMap { arr in
            arr.mapAllOrFailure { elem in parseString(elem, backtrace) }
        }
}

private func parseDefaultContainerOrientation(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<DefaultContainerOrientation> {
    parseString(raw, backtrace).flatMap {
        DefaultContainerOrientation(rawValue: $0)
            .orFailure(.semantic(backtrace, "Can't parse default container orientation '\($0)'"))
    }
}

private func parseWorkspaceToMonitorAssignment(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: [MonitorDescription]] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: [MonitorDescription]] = [:]
    for (workspaceName, rawMonitorDescription) in rawTable {
        result[workspaceName] = parseMonitorDescriptions(rawMonitorDescription, backtrace + .key(workspaceName), &errors)
    }
    return result
}

private func parseMonitorDescriptions(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [MonitorDescription] {
    if let array = raw.array {
        return array.enumerated()
            .map { (index, rawDesc) in parseMonitorDescription(rawDesc, backtrace + .index(index)).getOrNil(appendErrorTo: &errors) }
            .filterNotNil()
    } else {
        return parseMonitorDescription(raw, backtrace).getOrNil(appendErrorTo: &errors).asList()
    }
}

private func parseMonitorDescription(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<MonitorDescription> {
    let rawString: String
    if let string = raw.string {
        rawString = string
    } else if let int = raw.int {
        rawString = String(int)
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .int], actual: raw.type, backtrace))
    }

    return parseMonitorDescription(rawString).toParsedToml(backtrace)
}

private func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> [String: Mode] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors, mapping)
    }
    if !result.keys.contains(mainModeId) {
        errors += [.semantic(backtrace, "Please specify '\(mainModeId)' mode")]
    }
    return result
}

private func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> Mode {
    guard let rawTable: TOMLTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
        case "binding":
            result.bindings = parseBindings(value, backtrace, &errors, mapping)
        default:
            errors += [unknownKeyError(backtrace)]
        }
    }
    return result
}

extension Parsed where Failure == String {
    func toParsedToml(_ backtrace: TomlBacktrace) -> ParsedToml<Success> {
        mapError { .semantic(backtrace, $0) }
    }
}

private func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .flatMap { modifiers, key -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map { HotkeyBinding(modifiers, key, $0) }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.binding) {
                errors.append(.semantic(backtrace, "'\(binding.binding)' Binding redeclaration"))
            }
            result[binding.binding] = binding
        }
    }
    return result
}

private func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: Key]) -> ParsedToml<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedToml<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}

func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Bool> {
    raw.bool.orFailure(expectedActualTypeError(expected: .bool, actual: raw.type, backtrace))
}

indirect enum TomlBacktrace: CustomStringConvertible {
    case root
    case rootKey(String)
    case key(String)
    case index(Int)
    case pair(TomlBacktrace, TomlBacktrace)

    var description: String {
        switch self {
        case .root:
            error("Impossible")
        case .rootKey(let value):
            return value
        case .key(let value):
            return "." + value
        case .index(let index):
            return "[\(index)]"
        case .pair(let first, let second):
            return first.description + second.description
        }
    }

    static func + (lhs: TomlBacktrace, rhs: TomlBacktrace) -> TomlBacktrace {
        if case .root = lhs {
            if case .key(let newRoot) = rhs {
                return .rootKey(newRoot)
            } else {
                error("Impossible")
            }
        } else {
            return pair(lhs, rhs)
        }
    }
}

extension TOMLTable {
    func parseTable<T: Copyable>(
        _ initial: T,
        _ fieldsParser: [String: any ParserProtocol<T>],
        _ backtrace: TomlBacktrace,
        _ errors: inout [TomlParseError]
    ) -> T {
        var raw = initial

        for (key, value) in self {
            let backtrace: TomlBacktrace = backtrace + .key(key)
            if let parser = fieldsParser[key] {
                raw = parser.transformRawConfig(raw, value, backtrace, &errors)
            } else {
                errors.append(unknownKeyError(backtrace))
            }
        }

        return raw
    }
}

func unknownKeyError(_ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, "Unknown key")
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}
