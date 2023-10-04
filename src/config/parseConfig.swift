import TOMLKit
import HotKey

// todo convert all `error` during config parsing to returning defaults and reporting errors to where? Some kind of log?

func reloadConfig() {
    let rawConfig = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
    // todo mainMode activate/deactivate
    config = parseConfig(rawConfig ?? "").value // todo show errors to user
    syncStartAtLogin()
}

struct TomlParseError: Error, CustomStringConvertible {
    let backtrace: TomlBacktrace
    let message: String

    init(_ backtrace: TomlBacktrace, _ message: String) {
        self.backtrace = backtrace
        self.message = message
    }

    var description: String { "\(backtrace): \(message)" }
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
        error(e.debugDescription)
    } catch let e {
        error(e.localizedDescription)
    }

    var modes: [String: Mode]? = nil
    var errors: [TomlParseError] = []

    let key1 = "after-startup-command"
    var value1: Command? = nil

    let key2 = "use-padding-for-nested-containers-with-the-same-orientation"
    var value2: Bool? = nil

    let key3 = "auto-flatten-containers"
    var value3: Bool? = nil

    let key4 = "floating-windows-on-top"
    var value4: Bool? = nil

    let key5 = "main-layout"
    var value5: ConfigLayout? = nil

    let key6 = "focus-wrapping"
    var value6: FocusWrapping? = nil

    let key7 = "DEBUG-all-windows-are-floating"
    var value7: Bool? = nil

    let key8 = "start-at-login"
    var value8: Bool? = nil

    let key9 = "after-login-command"
    var value9: Command? = nil

    let key10 = "tray-icon-content"
    var value10: TrayIconContent? = nil

    let key11 = "tray-icon-workspaces-separator"
    var value11: String? = nil

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        switch key {
        case key1:
            (value1, errors) = parseCommand(value).toParsedTomlResult(backtrace).prependErrorsAndUnwrap(errors)
        case key2:
            (value2, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key3:
            (value3, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key4:
            (value4, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key5:
            (value5, errors) = parseMainLayout(value, backtrace).prependErrorsAndUnwrap(errors)
        case key6:
            (value6, errors) = parseFocusWrapping(value, backtrace).prependErrorsAndUnwrap(errors)
        case key7:
            (value7, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key8:
            (value8, errors) = parseBool(value, backtrace).prependErrorsAndUnwrap(errors)
        case key9:
            (value9, errors) = parseCommand(value).toParsedTomlResult(backtrace).prependErrorsAndUnwrap(errors)
        case key10:
            (value10, errors) = parseTrayIconContent(value, backtrace).prependErrorsAndUnwrap(errors)
        case key11:
            (value11, errors) = parseString(value, backtrace).prependErrorsAndUnwrap(errors)
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
        usePaddingForNestedContainersWithTheSameOrientation: value2 ?? defaultConfig.usePaddingForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: value3 ?? defaultConfig.autoFlattenContainers,
        floatingWindowsOnTop: value4 ?? defaultConfig.floatingWindowsOnTop,
        mainLayout: value5 ?? defaultConfig.mainLayout,
        focusWrapping: value6 ?? defaultConfig.focusWrapping,
        debugAllWindowsAreFloating: value7 ?? defaultConfig.debugAllWindowsAreFloating,
        startAtLogin: value8 ?? defaultConfig.startAtLogin,
        trayIconContent: value10 ?? defaultConfig.trayIconContent,
        trayIconWorkspacesSeparator: value11 ?? defaultConfig.trayIconWorkspacesSeparator,

        modes: modesOrDefault,
        workspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .map { (binding: HotkeyBinding) -> Command in binding.command }
            .compactMap { (command: Command) -> String? in (command as? WorkspaceCommand)?.workspaceName ?? nil }
    )
    return Writer(value: config, log: errors)
}

private func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<String> {
    raw.string.orFailure { expectedActualTypeError(expected: .string, actual: raw.type, backtrace) }
}

private func parseTrayIconContent(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<TrayIconContent> {
    parseString(raw, backtrace).flatMap {
        TrayIconContent(rawValue: $0).orFailure { TomlParseError(backtrace, "Can't parse tray-icon-content") }
    }
}

private func parseFocusWrapping(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<FocusWrapping> {
    parseString(raw, backtrace).flatMap {
        FocusWrapping(rawValue: $0).orFailure { TomlParseError(backtrace, "Can't parse focus wrapping") }
    }
}

private func parseMainLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<ConfigLayout> {
    parseString(raw, backtrace)
        .flatMap { parseLayout($0).mapError { TomlParseError(backtrace, $0) } }
        .flatMap { (layout: ConfigLayout) -> ParsedTomlResult<ConfigLayout> in
            layout == .main ? .failure(TomlParseError(backtrace, "main layout can't be 'main'")) : .success(layout)
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
        writer = writer.tell(TomlParseError(backtrace, "Please specify '\(mainModeId)' mode"))
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
        mapError { TomlParseError(backtrace, $0) }
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
            modifiersMap[String($0)].orFailure { TomlParseError(backtrace, "Can't parse modifiers in '\(raw)' binding") }
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ParsedTomlResult<Key> = rawKeys.last.flatMap { keysMap[String($0)] }
        .orFailure { TomlParseError(backtrace, "Can't parse the key in '\(raw)' binding") }
    return modifiers.flatMap { modifiers -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ParsedTomlResult<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}

private func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedTomlResult<Bool> {
    raw.bool.orFailure { expectedActualTypeError(expected: .bool, actual: raw.type, backtrace) }
}

// todo make private
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
    TomlParseError(backtrace, "Unknown key")
}

private func expectedActualTypeError(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    TomlParseError(backtrace, "Expected type is '\(expected)'. But actual type is '\(actual)'")
}
