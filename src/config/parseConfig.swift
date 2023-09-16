import Foundation
import TOMLKit
import HotKey

// todo convert all `error` during config parsing to returning defaults and reporting errors to where? Some kind of log?

let mainModeId = "main"
let defaultConfig =
    parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!))
var config: Config = defaultConfig

func reloadConfig() {
    let rawConfig = try? String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
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
        afterStartupCommand: value1 ?? defaultConfig.afterStartupCommand,
        usePaddingForNestedContainersWithTheSameOrientation: value2 ?? defaultConfig.usePaddingForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: value3 ?? defaultConfig.autoFlattenContainers,
        floatingWindowsOnTop: value4 ?? defaultConfig.floatingWindowsOnTop,
        modes: modes ?? defaultConfig.modes
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
        return CompositeCommand(subCommands: commands)
    } else {
        return expectedActualTypeError(expected: [.string, .array], actual: raw.type, backtrace)
    }
}

private func parseSingleCommand(_ raw: String, _ backtrace: TomlBacktrace) -> Command {
    let words = raw.split(separator: " ")
    let args = words[1...]
    let firstWord = String(words.first ?? "")
    if firstWord == "workspace" {
        return WorkspaceCommand(workspaceName: parseSingleArg(args, firstWord, backtrace))
    } else if firstWord == "mode" {
        return ModeCommand(idToActivate: parseSingleArg(args, firstWord, backtrace))
    } else if firstWord == "bash" {
        return BashCommand(bashCommand: raw.removePrefix("bash"))
    } else if firstWord == "focus" {
        let direction = FocusCommand.Direction(rawValue: parseSingleArg(args, firstWord, backtrace))
            ?? errorT("\(backtrace): Can't parse 'focus' direction")
        return FocusCommand(direction: direction)
    } else if firstWord == "move_through" {
        let direction = MoveThroughCommand.Direction(rawValue: parseSingleArg(args, firstWord, backtrace))
            ?? errorT("\(backtrace): Can't parse 'move_through' direction")
        return MoveThroughCommand(direction: direction)
    } else if raw == "reload_config" {
        return ReloadConfigCommand()
    } else if raw == "" {
        error("\(backtrace): Can't parse empty string command")
    } else {
        error("\(backtrace): Can't parse '\(raw)' command")
    }
}

private func parseSingleArg(_ args: ArraySlice<Swift.String.SubSequence>, _ command: String, _ backtrace: TomlBacktrace) -> String {
    args.singleOrNil().flatMap { String($0) } ?? errorT(
        "\(backtrace): \(command) must have only a single argument. But passed: '\(args.joined(separator: " "))'"
    )
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
    error("\(backtrace): Expected type is '\(expected)'. But actual type is '\(actual)'")
}

private func expectedActualTypeError<T>(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual, backtrace)
    } else {
        error("\(backtrace): Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'")
    }
}
