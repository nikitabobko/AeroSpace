import TOMLKit
import HotKey

func reloadConfig() {
    let configUrl = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml")
    let rawConfig = try? String(contentsOf: configUrl)
    let (parsedConfig, errors) = rawConfig?.lets { parseConfig($0) } ?? (defaultConfig, [])

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
            return "\(backtrace): \(message)"
        case .syntax(let message):
            return message
        }
    }
}

private typealias ParsedTomlResult<T> = Result<T, TomlParseError>

private extension Result {
    func unwrapAndAppendErrors(_ errors: inout [Failure]) -> Success? {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            errors += [error]
            return nil
        }
    }

    func getOrNils() -> (Success?, Failure?) {
        switch self {
        case .success(let success):
            return (success, nil)
        case .failure(let failure):
            return (nil, failure)
        }
    }
}

private extension ParserProtocol {
    func transformRawConfig(_ raw: RawConfig,
                            _ value: TOMLValueConvertible,
                            _ backtrace: TomlBacktrace,
                            _ errors: inout [TomlParseError]) -> RawConfig {
        raw.copy(keyPath, parse(value, backtrace).unwrapAndAppendErrors(&errors))
    }
}

private protocol ParserProtocol<T> {
    associatedtype T
    var keyPath: WritableKeyPath<RawConfig, T?> { get }
    var parse: (TOMLValueConvertible, TomlBacktrace) -> ParsedTomlResult<T> { get }
}

private struct Parser<T>: ParserProtocol {
    let keyPath: WritableKeyPath<RawConfig, T?>
    let parse: (TOMLValueConvertible, TomlBacktrace) -> ParsedTomlResult<T>

    init(_ keyPath: WritableKeyPath<RawConfig, T?>, _ parse: @escaping (TOMLValueConvertible, TomlBacktrace) -> ParsedTomlResult<T>) {
        self.keyPath = keyPath
        self.parse = parse
    }
}

private let parsers: [String: any ParserProtocol] = [
    "after-login-command": Parser(\.afterLoginCommand, { parseCommand($0).toParsedTomlResult($1) }),
    "after-startup-command": Parser(\.afterStartupCommand, { parseCommand($0).toParsedTomlResult($1) }),
    "indent-for-nested-containers-with-the-same-orientation": Parser(\.indentForNestedContainersWithTheSameOrientation, { parseInt($0, $1) }),
    "enable-normalization-flatten-containers": Parser(\.enableNormalizationFlattenContainers, { parseBool($0, $1) }),
    "floating-windows-on-top": Parser(\.floatingWindowsOnTop, { parseBool($0, $1) }),
    "default-root-container-layout": Parser(\.defaultRootContainerLayout, { parseLayout($0, $1) }),
    "start-at-login": Parser(\.startAtLogin, { parseBool($0, $1) }),
    "accordion-padding": Parser(\.accordionPadding, { parseInt($0, $1) }),
    "enable-normalization-opposite-orientation-for-nested-containers": Parser(\.enableNormalizationOppositeOrientationForNestedContainers, { parseBool($0, $1) }),
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

    var modes: [String: Mode]? = nil
    var errors: [TomlParseError] = []

    var raw = RawConfig()

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        if key == "mode" {
            modes = parseModes(value, backtrace, &errors)
        } else if let parser = parsers[key] {
            raw = parser.transformRawConfig(raw, value, backtrace, &errors)
        } else {
            errors += [unknownKeyError(backtrace)]
        }
    }

    let modesOrDefault = modes ?? defaultConfig.modes

    let config =  Config(
        afterLoginCommand: raw.afterLoginCommand ?? defaultConfig.afterLoginCommand,
        afterStartupCommand: raw.afterStartupCommand ?? defaultConfig.afterStartupCommand,
        indentForNestedContainersWithTheSameOrientation: raw.indentForNestedContainersWithTheSameOrientation ?? defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: raw.enableNormalizationFlattenContainers ?? defaultConfig.enableNormalizationFlattenContainers,
        floatingWindowsOnTop: raw.floatingWindowsOnTop ?? defaultConfig.floatingWindowsOnTop,
        defaultRootContainerLayout: raw.defaultRootContainerLayout ?? defaultConfig.defaultRootContainerLayout,
        startAtLogin: raw.startAtLogin ?? defaultConfig.startAtLogin,
        accordionPadding: raw.accordionPadding ?? defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: raw.enableNormalizationOppositeOrientationForNestedContainers ?? defaultConfig.enableNormalizationOppositeOrientationForNestedContainers,

        modes: modesOrDefault,
        preservedWorkspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .map { (binding: HotkeyBinding) -> Command in binding.command }
            .map { (command: Command) -> Command in (command as? CompositeCommand)?.subCommands.singleOrNil() ?? command }
            .compactMap { (command: Command) -> String? in (command as? WorkspaceCommand)?.workspaceName ?? nil }
    )
    return (config, errors)
}

private func parseInt(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<Int> {
    raw.int.orFailure { expectedActualTypeError(expected: .int, actual: raw.type, backtrace) }
}

private func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<String> {
    raw.string.orFailure { expectedActualTypeError(expected: .string, actual: raw.type, backtrace) }
}

private func parseLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<Layout> {
    parseString(raw, backtrace)
        .flatMap { Layout(rawValue: $0).orFailure(.semantic(backtrace, "Can't parse layout '\($0)'")) }
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

private extension ParsedCommand where Failure == String {
    func toParsedTomlResult(_ backtrace: TomlBacktrace) -> ParsedTomlResult<Success> {
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
        let (binding, error): (HotkeyBinding?, TomlParseError?) = parseBinding(binding, backtrace)
            .flatMap { (modifiers, key) -> ParsedTomlResult<HotkeyBinding> in
                // todo support parsing of implicit modes?
                parseCommand(rawCommand).toParsedTomlResult(backtrace).map { HotkeyBinding(modifiers, key, $0) }
            }
            .getOrNils()
        if let binding {
            result += [binding]
        }
        if let error {
            errors += [error]
        }
    }
    return result
}

private func parseBinding(_ raw: String, _ backtrace: TomlBacktrace) -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedTomlResult<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure { .semantic(backtrace, "Can't parse modifiers in '\(raw)' binding") }
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedTomlResult<Key> = rawKeys.last.flatMap { keysMap[String($0)] }
        .orFailure { .semantic(backtrace, "Can't parse the key in '\(raw)' binding") }
    return modifiers.flatMap { modifiers -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}

private func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<Bool> {
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
    .semantic(backtrace, "Expected type is '\(expected)'. But actual type is '\(actual)'")
}
