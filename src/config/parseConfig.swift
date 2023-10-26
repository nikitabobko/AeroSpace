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

    let key1 = "after-startup-command"
    var value1: Command? = nil

    let key2 = "indent-for-nested-containers-with-the-same-orientation"
    var value2: Int? = nil

    let key3 = "enable-normalization-flatten-containers"
    var value3: Bool? = nil

    let key4 = "floating-windows-on-top"
    var value4: Bool? = nil

    let key5 = "main-layout"
    var value5: ConfigLayout? = nil

    let key8 = "start-at-login"
    var value8: Bool? = nil

    let key9 = "after-login-command"
    var value9: Command? = nil

    let key12 = "accordion-padding"
    var value12: Int? = nil

    let key13 = "enable-normalization-opposite-orientation-for-nested-containers"
    var value13: Bool? = nil

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        switch key {
        case key1:
            value1 = parseCommand(value).toParsedTomlResult(backtrace).unwrapAndAppendErrors(&errors)
        case key2:
            value2 = parseInt(value, backtrace).unwrapAndAppendErrors(&errors)
        case key3:
            value3 = parseBool(value, backtrace).unwrapAndAppendErrors(&errors)
        case key4:
            value4 = parseBool(value, backtrace).unwrapAndAppendErrors(&errors)
        case key5:
            value5 = parseMainLayout(value, backtrace).unwrapAndAppendErrors(&errors)
        case key8:
            value8 = parseBool(value, backtrace).unwrapAndAppendErrors(&errors)
        case key9:
            value9 = parseCommand(value).toParsedTomlResult(backtrace).unwrapAndAppendErrors(&errors)
        case key12:
            value12 = parseInt(value, backtrace).unwrapAndAppendErrors(&errors)
        case key13:
            value13 = parseBool(value, backtrace).unwrapAndAppendErrors(&errors)
        case "mode":
            modes = parseModes(value, backtrace, &errors)
        default:
            errors += [unknownKeyError(backtrace)]
        }
    }

    let modesOrDefault = modes ?? defaultConfig.modes

    let config =  Config(
        afterStartupCommand: value1 ?? defaultConfig.afterStartupCommand,
        afterLoginCommand: value9 ?? defaultConfig.afterLoginCommand,
        indentForNestedContainersWithTheSameOrientation: value2 ?? defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: value3 ?? defaultConfig.enableNormalizationFlattenContainers,
        floatingWindowsOnTop: value4 ?? defaultConfig.floatingWindowsOnTop,
        mainLayout: value5 ?? defaultConfig.mainLayout,
        startAtLogin: value8 ?? defaultConfig.startAtLogin,
        accordionPadding: value12 ?? defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: value13 ?? defaultConfig.enableNormalizationOppositeOrientationForNestedContainers,

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

private func parseMainLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<ConfigLayout> {
    parseString(raw, backtrace)
        .flatMap { parseLayout($0).mapError { .semantic(backtrace, $0) } }
        .flatMap { (layout: ConfigLayout) -> ParsedTomlResult<ConfigLayout> in
            layout == .main ? .failure(.semantic(backtrace, "main layout can't be 'main'")) : .success(layout)
        }
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
