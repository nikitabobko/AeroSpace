import TOMLKit
import HotKey

func reloadConfig() {
    let rawConfig = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
    config = parseConfig(rawConfig ?? "").value // todo show errors to user
    activateMode(mainModeId)
    if !Bundle.appId.contains("debug") {
        syncStartAtLogin()
    }
}

enum TomlParseError: Error, CustomStringConvertible {
    case semantic(_ backtrace: TomlBacktrace, _ message: String)
    case syntax(_ message: String)

    var description: String {
        switch self {
        case .semantic(let backtrace, let message):
            return "\(backtrace): \(message)"
        case .syntax(let message):
            return "TOML parse error: \(message)"
        }
    }
}

private typealias ParsedTomlResult<T> = Result<T, TomlParseError>
typealias ParsedTomlWriter<T> = Writer<T, TomlParseError>

private extension Result {
    func prependErrorsAndUnwrap(_ existingErrors: [Failure]) -> (Success?, [Failure]) {
        switch self {
        case .success(let success):
            return (success, existingErrors)
        case .failure(let error):
            return (nil, existingErrors + [error])
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

func parseConfig(_ rawToml: String) -> ParsedTomlWriter<Config> {
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        return ParsedTomlWriter(value: defaultConfig, log: [.syntax(e.debugDescription)])
    } catch let e {
        return ParsedTomlWriter(value: defaultConfig, log: [.syntax(e.localizedDescription)])
    }

    var modes: [String: Mode]? = nil
    var errors: [TomlParseError] = []

    let key1 = "after-startup-command"
    var value1: Command? = nil

    let key2 = "indent-for-nested-containers-with-the-same-orientation"
    var value2: Int? = nil

    let key3 = "auto-flatten-containers"
    var value3: Bool? = nil

    let key4 = "floating-windows-on-top"
    var value4: Bool? = nil

    let key5 = "main-layout"
    var value5: ConfigLayout? = nil

    let key7 = "DEBUG-all-windows-are-floating"
    var value7: Bool? = nil

    let key8 = "start-at-login"
    var value8: Bool? = nil

    let key9 = "after-login-command"
    var value9: Command? = nil

    let key12 = "accordion-padding"
    var value12: Int? = nil

    let key13 = "auto-opposite-orientation-for-nested-containers"
    var value13: Bool? = nil

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        switch key {
        case key1:
            (value1, errors) = parseCommand(value).toParsedTomlResult(backtrace).prependErrorsAndUnwrap(errors)
        case key2:
            (value2, errors) = parseInt(value, backtrace).prependErrorsAndUnwrap(errors)
        case key3:
            (value3, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key4:
            (value4, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key5:
            (value5, errors) = parseMainLayout(value, backtrace).prependErrorsAndUnwrap(errors)
        case key7:
            (value7, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key8:
            (value8, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key9:
            (value9, errors) = parseCommand(value).toParsedTomlResult(backtrace).prependErrorsAndUnwrap(errors)
        case key12:
            (value12, errors) = parseInt(value, backtrace).prependErrorsAndUnwrap(errors)
        case key13:
            (value13, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case "mode":
            (modes, errors) = parseModes(value, backtrace).prependLogAndUnwrap(errors)
        default:
            errors += [unknownKeyError(backtrace)]
        }
    }

    let modesOrDefault = modes ?? defaultConfig.modes

    let config =  Config(
        afterStartupCommand: value1 ?? defaultConfig.afterStartupCommand,
        afterLoginCommand: value9 ?? defaultConfig.afterLoginCommand,
        indentForNestedContainersWithTheSameOrientation: value2 ?? defaultConfig.indentForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: value3 ?? defaultConfig.autoFlattenContainers,
        floatingWindowsOnTop: value4 ?? defaultConfig.floatingWindowsOnTop,
        mainLayout: value5 ?? defaultConfig.mainLayout,
        debugAllWindowsAreFloating: value7 ?? defaultConfig.debugAllWindowsAreFloating,
        startAtLogin: value8 ?? defaultConfig.startAtLogin,
        accordionPadding: value12 ?? defaultConfig.accordionPadding,
        autoOppositeOrientationForNestedContainers: value13 ?? defaultConfig.autoOppositeOrientationForNestedContainers,

        modes: modesOrDefault,
        preservedWorkspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .map { (binding: HotkeyBinding) -> Command in binding.command }
            .map { (command: Command) -> Command in (command as? CompositeCommand)?.subCommands.singleOrNil() ?? command }
            .compactMap { (command: Command) -> String? in (command as? WorkspaceCommand)?.workspaceName ?? nil }
    )
    return Writer(value: config, log: errors)
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

private func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlWriter<[String: Mode]> {
    var writer: ParsedTomlWriter<[String: Mode]> = ParsedTomlWriter(value: [:], log: [])
    guard let rawTable = raw.table else {
        return writer.tell(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
    }
    writer = rawTable.reduce(writer) { (accumulator: ParsedTomlWriter<[String: Mode]>, element: (String, TOMLValueConvertible)) -> ParsedTomlWriter<[String: Mode]> in
        let (key, value) = element
        return accumulator.flatMap {
            var prev: [String: Mode] = $0
            return parseMode(value, backtrace + .key(key)).map {
                prev[key] = $0
                return prev
            }
        }
    }
    if !writer.value.keys.contains(mainModeId) {
        writer = writer.tell(.semantic(backtrace, "Please specify '\(mainModeId)' mode"))
    }
    return writer
}

private func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlWriter<Mode> {
    var writer = ParsedTomlWriter(
        value: Mode(name: nil, bindings: []),
        log: []
    )
    guard let rawTable: TOMLTable = raw.table else {
        return writer.tell(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
    }

    for (key, value) in rawTable {
        let keyBacktrace = backtrace + .key(key)
        switch key {
        case "binding":
            let (value1, errors) = parseBindings(value, keyBacktrace).toTuple()
            writer = writer.tell(errors).map { $0.copy(\.bindings, value1) }
        default:
            writer = writer.tell(unknownKeyError(keyBacktrace))
        }
    }
    return writer
}

private extension ParsedCommand where Failure == String {
    func toParsedTomlResult(_ backtrace: TomlBacktrace) -> ParsedTomlResult<Success> {
        mapError { .semantic(backtrace, $0) }
    }
}

private func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlWriter<[HotkeyBinding]> {
    guard let rawTable = raw.table else {
        return ParsedTomlWriter(value: [], log: [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)])
    }
    var bindings: [HotkeyBinding] = []
    var errors: [TomlParseError] = []
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let keyBacktrace = backtrace + .key(binding)
        let (binding, error): (HotkeyBinding?, TomlParseError?) = parseBinding(binding, keyBacktrace)
            .flatMap { (modifiers, key) -> ParsedTomlResult<HotkeyBinding> in
                // todo support parsing of implicit modes?
                parseCommand(rawCommand).toParsedTomlResult(keyBacktrace).map { HotkeyBinding(modifiers, key, $0) }
            }
            .getOrNils()
        if let binding {
            bindings += [binding]
        }
        if let error {
            errors += [error]
        }
    }
    return Writer(value: bindings, log: errors)
}

private func parseBinding(_ raw: String, _ backtrace: TomlBacktrace) -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedTomlResult<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapOrFailure {
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
