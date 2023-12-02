import TOMLKit
import HotKey

func reloadConfig() {
    let configUrl = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: isDebug ? ".aerospace-debug.toml" : ".aerospace.toml")
    let (parsedConfig, errors) = parseConfig((try? String(contentsOf: configUrl)) ?? "")

    if !errors.isEmpty {
        activateMode(mainModeId)
        showConfigParsingErrorsToUser(errors, configUrl: configUrl)
        return
    }
    config = parsedConfig
    activateMode(mainModeId)
    if !Bundle.appId.contains("debug") {
        syncStartAtLogin()
    }
}

private func showConfigParsingErrorsToUser(_ errors: [TomlParseError], configUrl: URL) {
    let message =
        """
        ####################################
        ### AEROSPACE CONFIG PARSE ERROR ###
        ####################################

        Failed to parse \(configUrl.absoluteURL.path)

        \(errors.map(\.description).joined(separator: "\n"))
        """
    showMessageToUser(filename: "config-parse-error.txt", message: message)
}

enum TomlParseError: Error, CustomStringConvertible {
    case semantic(_ backtrace: TomlBacktrace, _ message: String)
    case syntax(_ message: String)

    var description: String {
        switch self {
        case .semantic(let backtrace, let message):
            if case .root("") = backtrace { // todo Make 'split' + flatten normalization prettier
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
        raw.copy(keyPath, parse(value, backtrace, &errors).getOrNil(appendErrorTo: &errors))
    }
}

protocol ParserProtocol<S> {
    associatedtype T
    associatedtype S where S : Copyable
    var keyPath: WritableKeyPath<S, T?> { get }
    var parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T> { get }
}

struct Parser<S: Copyable, T>: ParserProtocol {
    let keyPath: WritableKeyPath<S, T?>
    let parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T>

    init(_ keyPath: WritableKeyPath<S, T?>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> T) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedToml<T> in .success(parse(raw, backtrace, &errors)) }
    }

    init(_ keyPath: WritableKeyPath<S, T?>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedToml<T> in parse(raw, backtrace) }
    }
}

private let parsers: [String: any ParserProtocol<RawConfig>] = [
    "after-login-command": Parser(\.afterLoginCommand, { parseCommandOrCommands($0).toParsedToml($1) }),
    "after-startup-command": Parser(\.afterStartupCommand, { parseCommandOrCommands($0).toParsedToml($1) }),

    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, parseBool),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, parseBool),

    "non-empty-workspaces-root-containers-layout-on-startup": Parser(\.nonEmptyWorkspacesRootContainersLayoutOnStartup, parseStartupRootContainerLayout),

    "default-root-container-layout": Parser(\.defaultRootContainerLayout, parseLayout),
    "default-root-container-orientation": Parser(\.defaultRootContainerOrientation, parseDefaultContainerOrientation),

    "indent-for-nested-containers-with-the-same-orientation": Parser(\.indentForNestedContainersWithTheSameOrientation, parseInt),
    "start-at-login": Parser(\.startAtLogin, parseBool),
    "accordion-padding": Parser(\.accordionPadding, parseInt),

    "mode": Parser(\.modes, parseModes),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, parseWorkspaceToMonitorAssignment),
    "on-window-detected": Parser(\.onWindowDetected, parseOnWindowDetectedArray)
]

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

    var raw = RawConfig()

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        if let parser = parsers[key] {
            raw = parser.transformRawConfig(raw, value, backtrace, &errors)
        } else {
            errors += [unknownKeyError(backtrace)]
        }
    }

    let modesOrDefault = raw.modes ?? defaultConfig.modes

    let config: Config = Config(
        afterLoginCommand: raw.afterLoginCommand ?? defaultConfig.afterLoginCommand,
        afterStartupCommand: raw.afterStartupCommand ?? defaultConfig.afterStartupCommand,
        indentForNestedContainersWithTheSameOrientation: raw.indentForNestedContainersWithTheSameOrientation ?? defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: raw.enableNormalizationFlattenContainers ?? defaultConfig.enableNormalizationFlattenContainers,
        nonEmptyWorkspacesRootContainersLayoutOnStartup: raw.nonEmptyWorkspacesRootContainersLayoutOnStartup ?? defaultConfig.nonEmptyWorkspacesRootContainersLayoutOnStartup,
        defaultRootContainerLayout: raw.defaultRootContainerLayout ?? defaultConfig.defaultRootContainerLayout,
        defaultRootContainerOrientation: raw.defaultRootContainerOrientation ?? defaultConfig.defaultRootContainerOrientation,
        startAtLogin: raw.startAtLogin ?? defaultConfig.startAtLogin,
        accordionPadding: raw.accordionPadding ?? defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: raw.enableNormalizationOppositeOrientationForNestedContainers ?? defaultConfig.enableNormalizationOppositeOrientationForNestedContainers,

        workspaceToMonitorForceAssignment: raw.workspaceToMonitorForceAssignment ?? [:],
        modes: modesOrDefault,
        onWindowDetected: raw.onWindowDetected ?? [],

        preservedWorkspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .compactMap { (binding: HotkeyBinding) -> String? in
                (binding.commands.singleOrNil() as? WorkspaceCommand)?.workspaceName
                    ?? (binding.commands.singleOrNil() as? MoveNodeToWorkspaceCommand)?.targetWorkspaceName
                    ?? nil
            }
            + (raw.workspaceToMonitorForceAssignment ?? [:]).keys
    )
    if config.enableNormalizationFlattenContainers {
        let containsSplitCommand = config.modes.values.lazy.flatMap { $0.bindings }
            .flatMap { $0.commands }
            .contains { $0 is SplitCommand }
        if containsSplitCommand {
            errors += [.semantic(.root(""), // todo Make 'split' + flatten normalization prettier
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

private func parseInt(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    raw.int.orFailure { expectedActualTypeError(expected: .int, actual: raw.type, backtrace) }
}

func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    raw.string.orFailure { expectedActualTypeError(expected: .string, actual: raw.type, backtrace) }
}

private func parseStartupRootContainerLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<StartupRootContainerLayout> {
    parseString(raw, backtrace)
        .flatMap {
            StartupRootContainerLayout(rawValue: $0)
                .orFailure(.semantic(backtrace, "Can't parse. possible values: (smart|tiles|accordion)"))
        }
}

private func parseLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Layout> {
    parseString(raw, backtrace)
        .flatMap { $0.parseLayout().orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
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
        return array.withIndex
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

    if let int = Int(rawString) {
        return int >= 1
            ? .success(.sequenceNumber(int))
            : .failure(.semantic(backtrace, "Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal"))
    }
    if rawString == "main" {
        return .success(.main)
    }
    if rawString == "secondary" {
        return .success(.secondary)
    }

    return rawString.isEmpty
        ? .failure(.semantic(backtrace, "Empty string is an illegal monitor description"))
        : parseCaseInsensitiveRegex(rawString).toParsedToml(backtrace).map(MonitorDescription.pattern)
}

func parseCaseInsensitiveRegex(_ raw: String) -> Parsed<Regex<AnyRegexOutput>> {
    (try? Regex(raw)).orFailure("Can't parse '\(raw)' regex").map { $0.ignoresCase() }
}

private func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: Mode] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors)
    }
    if !result.keys.contains(mainModeId) {
        errors += [.semantic(backtrace, "Please specify '\(mainModeId)' mode")]
    }
    return result
}

private func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Mode {
    guard let rawTable: TOMLTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
        case "binding":
            result.bindings = parseBindings(value, backtrace, &errors)
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

private func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return []
    }
    var result: [HotkeyBinding] = []
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace)
            .flatMap { (modifiers, key) -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map { HotkeyBinding(modifiers, key, $0) }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            result += [binding]
        }
    }
    return result
}

private func parseBinding(_ raw: String, _ backtrace: TomlBacktrace) -> ParsedToml<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure { .semantic(backtrace, "Can't parse modifiers in '\(raw)' binding") }
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedToml<Key> = rawKeys.last.flatMap { keysMap[String($0)] }
        .orFailure { .semantic(backtrace, "Can't parse the key in '\(raw)' binding") }
    return modifiers.flatMap { modifiers -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedToml<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}

func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Bool> {
    raw.bool.orFailure { expectedActualTypeError(expected: .bool, actual: raw.type, backtrace) }
}

indirect enum TomlBacktrace: CustomStringConvertible {
    case root(String)
    case key(String)
    case index(Int)
    case pair((TomlBacktrace, TomlBacktrace))

    var description: String {
        switch self {
        case .root(let value):
            return value
        case .key(let value):
            return "." + value
        case .index(let index):
            return "[\(index)]"
        case .pair((let first, let second)):
            return first.description + second.description
        }
    }

    static func +(lhs: TomlBacktrace, rhs: TomlBacktrace) -> TomlBacktrace {
        pair((lhs, rhs))
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
