import TOMLKit
import HotKey

// todo convert all `error` during config parsing to returning defaults and reporting errors to where? Some kind of log?

let mainModeId = "main"
let defaultConfig =
    parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!))
var config: Config = defaultConfig

func reloadConfig() {
    let rawConfig = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
    // todo mainMode activate/deactivate
    config = parseConfig(rawConfig ?? "")
}

func parseConfig(_ rawToml: String) -> Config {
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        error(e.debugDescription)
    } catch let e {
        error(e.localizedDescription)
    }

    var modes: [String: Mode]? = nil

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

    for (key, value) in rawTable {
        let backtrace: TomlBacktrace = .root(key)
        switch key {
        case key1:
            value1 = parseCommand(value, backtrace)
        case key2:
            value2 = parseBool(value, backtrace)
        case key3:
            value3 = parseBool(value, backtrace)
        case key4:
            value4 = parseBool(value, backtrace)
        case key5:
            value5 = parseMainLayout(value, backtrace)
        case key6:
            value6 = parseFocusWrapping(value, backtrace)
        case "mode":
            modes = parseModes(value, backtrace)
        default:
            unknownKeyError(backtrace)
        }
    }

    let modesOrDefault = modes ?? defaultConfig.modes

    return Config(
        afterStartupCommand: value1 ?? defaultConfig.afterStartupCommand,
        usePaddingForNestedContainersWithTheSameOrientation: value2 ?? defaultConfig.usePaddingForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: value3 ?? defaultConfig.autoFlattenContainers,
        floatingWindowsOnTop: value4 ?? defaultConfig.floatingWindowsOnTop,
        mainLayout: value5 ?? defaultConfig.mainLayout,
        focusWrapping: value6 ?? defaultConfig.focusWrapping,

        modes: modesOrDefault,
        workspaceNames: modesOrDefault.values.lazy
            .flatMap { (mode: Mode) -> [HotkeyBinding] in mode.bindings }
            .flatMap { (binding: HotkeyBinding) -> [any Command] in
                (binding.command as? CompositeCommand)?.subCommands ?? [binding.command]
            }
            .compactMap { (command: Command) -> String? in (command as? WorkspaceCommand)?.workspaceName ?? nil }
    )
}

private func parseFocusWrapping(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> FocusWrapping {
    let rawString = raw.string ?? expectedActualTypeError(expected: .string, actual: raw.type, backtrace)
    return FocusWrapping(rawValue: rawString) ?? errorT("\(backtrace): Can't parse focus wrapping")
}

private func parseMainLayout(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ConfigLayout {
    let rawString = raw.string ?? expectedActualTypeError(expected: .string, actual: raw.type, backtrace)
    let layout = parseLayout(rawString, backtrace)
    if layout == .main {
        error("\(backtrace): main layout can't be '\(layout)'")
    }
    return layout
}

private func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> [String: Mode] {
    let rawTable = raw.table ?? expectedActualTypeError(expected: .table, actual: raw.type, backtrace)
    var result: [String: Mode] = [:]
    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key))
    }
    if !result.keys.contains(mainModeId) {
        error("\(backtrace) is expected to contain 'main' mode")
    }
    return result
}

private func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Mode {
    let rawTable = raw.table ?? expectedActualTypeError(expected: .table, actual: raw.type, backtrace)

    let key1 = "binding"
    var value1: [HotkeyBinding] = []

    for (key, value) in rawTable {
        let keyBacktrace = backtrace + .key(key)
        switch key {
        case key1:
            value1 = parseBindings(value, keyBacktrace)
        default:
            unknownKeyError(keyBacktrace)
        }
    }
    return Mode(
        name: nil,
        bindings: value1
    )
}

private func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> [HotkeyBinding] {
    let rawTable = raw.table ?? expectedActualTypeError(expected: .table, actual: raw.type, backtrace)
    return rawTable.map { (binding: String, value: TOMLValueConvertible) in
        let keyBacktrace = backtrace + .key(binding)
        let (modifiers, key) = parseBinding(binding, keyBacktrace)
        return HotkeyBinding(modifiers, key, parseCommand(value, keyBacktrace))
    }
}

private func parseBinding(_ raw: String, _ backtrace: TomlBacktrace) -> (NSEvent.ModifierFlags, Key) {
    let rawKeys = raw.split(separator: "-")
    let modifiers: [NSEvent.ModifierFlags] = rawKeys.dropLast()
        .map { modifiersMap[String($0)] ?? errorT("\(backtrace): Can't parse '\(raw)' binding") }
    let key = rawKeys.last.flatMap { keysMap[String($0)] } ?? errorT("\(backtrace): Can't parse '\(raw)' binding")
    return (NSEvent.ModifierFlags(modifiers), key)
}

private func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Bool {
    raw.bool ?? expectedActualTypeError(expected: .bool, actual: raw.type, backtrace)
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

private func unknownKeyError(_ backtrace: TomlBacktrace) -> Never {
    error("Unknown key '\(backtrace)'")
}

private func expectedActualTypeError<T>(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    error("\(backtrace): Expected type is '\(expected)'. But actual type is '\(actual)'")
}
