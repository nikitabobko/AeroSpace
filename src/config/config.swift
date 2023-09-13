import Foundation
import TOMLKit
import HotKey

// todo convert all `error` during config parsing to returning defaults and reporting errors to where? Some kind of log?

struct Config {
    let afterStartupCommand: Command
    let usePaddingForNestedContainersWithTheSameOrientation: Bool
    let autoFlattenContainers: Bool
    let floatingWindowsOnTop: Bool
}

struct ConfigRoot {
    let config: Config
    let modes: [Mode]
}

struct Mode {
    let id: String
    /// User visible name. Optional. todo drop it?
    let name: String?
    let bindings: [HotkeyBinding]
}

var config: ConfigRoot = defaultConfig

func reloadConfig() {
    let rawConfig = String.fromUrl(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".aerospace.toml"))
    config = parseConfigRoot(rawConfig ?? "")
}

private func parseConfigRoot(_ rawToml: String) -> ConfigRoot {
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        error(e.debugDescription)
    } catch let e {
        error(e.localizedDescription)
    }
    var config: Config? = nil
    var modes: [Mode] = []
    for (key, value) in rawTable {
        switch key {
        case "config":
            config = parseConfig(value, .root("config"))
        case "mode":
            modes = parseModes(value, .root("mode"))
        default:
            unknownKeyError(key, .root(key))
        }
    }
    return ConfigRoot(
        config: config ?? defaultConfig.config,
        modes: modes
    )
}

private func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> [Mode] {
    // todo
    []
}

private func unknownKeyError(_ key: String, _ backtrace: TomlBacktrace) -> Never {
    error("\(backtrace): Unknown key '\(key)'")
}

private func expectedActualTypeError<T>(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    expectedActualTypeError(expected: [expected], actual: actual, backtrace)
}

private func expectedActualTypeError<T>(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    error("\(backtrace): Expected type is \(expected.map { $0.description }.joined(separator: " or ")). But actual type is \(actual)")
}

private func parseConfig(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Config {
    let rawTable = raw.table ?? expectedActualTypeError(expected: .table, actual: raw.type, backtrace)

    let key1 = "after-startup-command"
    var value1: Command = defaultConfig.config.afterStartupCommand

    let key2 = "use-padding-for-nested-containers-with-the-same-orientation"
    var value2: Bool = defaultConfig.config.usePaddingForNestedContainersWithTheSameOrientation

    let key3 = "auto-flatten-containers"
    var value3: Bool = defaultConfig.config.autoFlattenContainers

    let key4 = "floating-windows-on-top"
    var value4: Bool = defaultConfig.config.floatingWindowsOnTop

    for (key, value) in rawTable {
        let keyBacktrace = backtrace + .key(key)
        switch key {
        case key1:
            value1 = parseCommand(value, keyBacktrace)
        case key2:
            value2 = parseBool(value, keyBacktrace)
        case key3:
            value3 = parseBool(value, keyBacktrace)
        case key4:
            value4 = parseBool(value, keyBacktrace)
        default:
            unknownKeyError(key, backtrace + .key(key))
        }
    }

    return Config(
        afterStartupCommand: value1,
        usePaddingForNestedContainersWithTheSameOrientation: value2,
        autoFlattenContainers: value3,
        floatingWindowsOnTop: value4
    )
}

private func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Bool {
    raw.bool ?? expectedActualTypeError(expected: .bool, actual: raw.type, backtrace)
}

class HotkeyBinding {
    let modifiers: NSEvent.ModifierFlags
    let key: Key
    let command: Command
    private var hotKey: HotKey? = nil

    init(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ command: Command) {
        self.modifiers = modifiers
        self.key = key
        self.command = command
    }

    func activate() {
        hotKey = HotKey(key: key, modifiers: modifiers, keyUpHandler: command.run)
    }

    func deactivate() {
        hotKey = nil
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
