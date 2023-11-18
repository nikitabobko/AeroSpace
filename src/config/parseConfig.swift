import TOMLKit
import HotKey

func reloadConfig() {
    let configUrl = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: isRelease ? ".aerospace.toml" : ".aerospace-debug.toml")
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
    showMessageToUser(
        filename: "config-parse-error.txt",
        message: message
    )
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

private typealias ParsedToml<T> = Result<T, TomlParseError>

private extension ParserProtocol {
    func transformRawConfig(_ raw: RawConfig,
                            _ value: TOMLValueConvertible,
                            _ backtrace: TomlBacktrace,
                            _ errors: inout [TomlParseError]) -> RawConfig {
        raw.copy(keyPath, parse(value, backtrace, &errors).getOrNil(appendErrorTo: &errors))
    }
}

private protocol ParserProtocol<T> {
    associatedtype T
    var keyPath: WritableKeyPath<RawConfig, T?> { get }
    var parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T> { get }
}

private struct Parser<T>: ParserProtocol {
    let keyPath: WritableKeyPath<RawConfig, T?>
    let parse: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T>

    init(_ keyPath: WritableKeyPath<RawConfig, T?>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T>) {
        self.keyPath = keyPath
        self.parse = parse
    }

    init(_ keyPath: WritableKeyPath<RawConfig, T?>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedToml<T> in parse(raw, backtrace) }
    }
}

private let parsers: [String: any ParserProtocol] = [
    "after-login-command": Parser(\.afterLoginCommand, { parseCommandOrCommands($0).toParsedToml($1) }),
    "after-startup-command": Parser(\.afterStartupCommand, { parseCommandOrCommands($0).toParsedToml($1) }),

    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, { parseBool($0, $1) }),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, { parseBool($0, $1) }),

    "default-root-container-layout": Parser(\.defaultRootContainerLayout, { parseLayout($0, $1) }),
    "default-root-container-orientation": Parser(\.defaultRootContainerOrientation, { parseDefaultContainerOrientation($0, $1) }),

    "indent-for-nested-containers-with-the-same-orientation": Parser(\.indentForNestedContainersWithTheSameOrientation, { parseInt($0, $1) }),
    "start-at-login": Parser(\.startAtLogin, { parseBool($0, $1) }),
    "accordion-padding": Parser(\.accordionPadding, { parseInt($0, $1) }),

    "mode": Parser(\.modes, { .success(parseModes($0, $1, &$2)) }),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, { .success(parseWorkspaceToMonitorAssignment($0, $1, &$2)) }),
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
        defaultRootContainerLayout: raw.defaultRootContainerLayout ?? defaultConfig.defaultRootContainerLayout,
        defaultRootContainerOrientation: raw.defaultRootContainerOrientation ?? defaultConfig.defaultRootContainerOrientation,
        startAtLogin: raw.startAtLogin ?? defaultConfig.startAtLogin,
        accordionPadding: raw.accordionPadding ?? defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: raw.enableNormalizationOppositeOrientationForNestedContainers ?? defaultConfig.enableNormalizationOppositeOrientationForNestedContainers,
        workspaceToMonitorForceAssignment: raw.workspaceToMonitorForceAssignment ?? [:],

        modes: modesOrDefault,
        preservedWorkspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .compactMap { (binding: HotkeyBinding) -> String? in (binding.commands.singleOrNil() as? WorkspaceCommand)?.workspaceName ?? nil }
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

private func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    raw.string.orFailure { expectedActualTypeError(expected: .string, actual: raw.type, backtrace) }
}

private func parseLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Layout> {
    parseString(raw, backtrace)
        .flatMap { Layout(rawValue: $0).orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
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

    let pattern = (try? Regex(rawString))?.lets { MonitorDescription.pattern($0.ignoresCase()) }

    return rawString.isEmpty
        ? .failure(.semantic(backtrace, "Empty string is an illegal monitor description"))
        : pattern.orFailure(.semantic(backtrace, "Can't parse '\(rawString)' regex"))
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

private extension Parsed where Failure == String {
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
                // todo support parsing of implicit modes?
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

private func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Bool> {
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

private func unknownKeyError(_ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, "Unknown key")
}

private func expectedActualTypeError(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

private func expectedActualTypeError(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}
