import Foundation
import TOMLKit
import HotKey

// todo convert all `error` during config parsing to returning defaults and reporting errors to where? Some kind of log?

let mainModeId = "main"
var config: Config = defaultConfig

func reloadConfig() {
    let rawConfig = String.fromUrl(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
    config = parseConfig(rawConfig ?? "")
}

private func parseConfig(_ rawToml: String) -> Config {
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        error(e.debugDescription)
    } catch let e {
        error(e.localizedDescription)
    }

    var modes: [String: Mode] = defaultConfig.modes

    let key1 = "after-startup-command"
    var value1: Command = defaultConfig.afterStartupCommand

    let key2 = "use-padding-for-nested-containers-with-the-same-orientation"
    var value2: Bool = defaultConfig.usePaddingForNestedContainersWithTheSameOrientation

    let key3 = "auto-flatten-containers"
    var value3: Bool = defaultConfig.autoFlattenContainers

    let key4 = "floating-windows-on-top"
    var value4: Bool = defaultConfig.floatingWindowsOnTop

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
        case "mode":
            modes = parseModes(value, backtrace)
        default:
            unknownKeyError(backtrace)
        }
    }

    return Config(
        afterStartupCommand: value1,
        usePaddingForNestedContainersWithTheSameOrientation: value2,
        autoFlattenContainers: value3,
        floatingWindowsOnTop: value4,
        modes: modes
    )
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

private func parseCommand(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Command {
    if let rawString = raw.string {
        return parseSingleCommand(rawString, backtrace)
    } else if let rawArray = raw.array {
        let commands: [Command] = (0..<rawArray.count).map { index in
            let indexBacktrace = backtrace + .index(index)
            let rawString: String = rawArray[index].string ??
                expectedActualTypeError(expected: .string, actual: rawArray[index].type, indexBacktrace)
            return parseSingleCommand(rawString, indexBacktrace)
        }
        return ChainedCommand(subCommands: commands)
    } else {
        return expectedActualTypeError(expected: [.string, .array], actual: raw.type, backtrace)
    }
}

private func parseSingleCommand(_ raw: String, _ backtrace: TomlBacktrace) -> Command {
    let words = raw.split(separator: " ")
    let args = words[1...]
    switch words.first {
    case "workspace":
        let name = args.singleOrNil() ?? errorT(
                "\(backtrace): Can't parse 'workspace' command arguments: '\(args.joined())'. Expected: a single arg"
        )
        return WorkspaceCommand(workspaceName: String(name))
    case "mode":
        let id = args.singleOrNil() ?? errorT(
                "\(backtrace): Can't parse 'mode' command arguments: '\(args.joined())'. Expected: a single arg"
        )
        return ModeCommand(idToActivate: String(id))
    case "bash":
        return BashCommand(bashCommand: raw.removePrefix("bash"))
    case "":
        error("\(backtrace): Can't parse empty string command")
    default:
        error("\(backtrace): Can't parse '\(raw)' command")
    }
}

private indirect enum TomlBacktrace: CustomStringConvertible {
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
    error("\(backtrace): Expected type is \(expected). But actual type is \(actual)")
}

private func expectedActualTypeError<T>(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual, backtrace)
    } else {
        error("\(backtrace): Expected types are \(expected.map { $0.description }.joined(separator: " or ")). But actual type is \(actual)")
    }
}
