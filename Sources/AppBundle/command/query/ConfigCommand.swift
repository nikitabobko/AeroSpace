import AppKit
import Common

struct ConfigCommand: Command {
    let args: ConfigCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
            switch args.mode {
                case .getKey(let key):
                    return getKey(state, args: args, key: key)
                case .majorKeys:
                    let out = """
                        .
                        mode
                        \(config.modes.keys.map { "mode.\($0).binding" }.joined(separator: "\n"))
                        """
                    return state.succCmd(msg: out)
                case .allKeys:
                    let configMap = buildConfigMap()
                    var allKeys: [String] = []
                    configMap.dumpAllKeysRecursive(path: ".", result: &allKeys)
                    return state.succCmd(msg: allKeys.joined(separator: "\n"))
                case .configPath:
                    return state.succCmd(msg: configUrl.absoluteURL.path)
            }
    }
}

private extension String {
    func toKeyPath() -> Result<[String], String> {
        if self == "." { return .success([]) }
        if isEmpty { return .failure("Invalid empty key") }
        if self.contains("..") { return .failure("Invalid key '\(self)'") }
        if self.hasSuffix(".") { return .failure("Invalid key '\(self)'") }
        return .success(self.split(separator: ".", omittingEmptySubsequences: false).map(String.init))
    }
}

private func getKey(_ state: CommandMutableState, args: ConfigCmdArgs, key: String) -> Bool {
    let keyPath: [String]
    switch key.toKeyPath() {
        case .success(let _keyPath): keyPath = _keyPath
        case .failure(let error):
            return state.failCmd(msg: error)
    }
    var configMap: ConfigMapValue
    switch buildConfigMap().find(keyPath: keyPath) {
        case .success(let value):
            configMap = value
        case .failure(let error):
            return state.failCmd(msg: error)
    }
    if args.keys {
        switch configMap {
            case .scalar(let scalar):
                return state.failCmd(msg: "--keys flag cannot be applied to scalar object '\(scalar)'")
            case .map(let map):
                configMap = .array(map.keys.map { .scalar(.string($0)) })
            case .array(let array):
                configMap = .array((0..<array.count).map { .scalar(.int($0)) })
        }
    }
    if args.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let _json = Result { try encoder.encode(configMap) }.flatMap {
            String(data: $0, encoding: .utf8).flatMap(Result.success) ?? .failure("Can't convert json Data to String")
        }
        return switch _json {
            case .success(let json): state.succCmd(msg: json)
            case .failure(let error): state.failCmd(msg: error.localizedDescription)
        }
    } else {
        switch configMap {
            case .scalar(let scalar):
                return state.succCmd(msg: scalar.describe)
            case .map:
                return state.failCmd(msg: "Complicated objects can be printed only with --json flag. " +
                    "Alternatively, you can try to inspect keys of the object with --keys flag")
            case .array(let array):
                let plainArray: Result<[String], String> = array.mapAllOrFailure {
                    switch $0 {
                        case .scalar(let scalar): .success(scalar.describe)
                        default: .failure("Printing array of non-string objects is supported only with --json flag." +
                            "Alternatively, you can try to inspect keys of the object with --keys flag")
                    }
                }
                return switch plainArray {
                    case .success(let array): state.succCmd(msg: array.sorted().joined(separator: "\n"))
                    case .failure(let error): state.failCmd(msg: error)
                }
        }
    }
}

extension ConfigMapValue {
    func find(keyPath: [String]) -> Result<ConfigMapValue, String> {
        if let key = keyPath.first {
            switch self {
                case .scalar(let scalar):
                    return .failure("Can't dereference scalar value '\(scalar.describe)'")
                case .map(let map):
                    if let child = map[key] {
                        return child.find(keyPath: Array(keyPath[1...]))
                    } else {
                        return .failure("No value at key token '\(key)'")
                    }
                case .array(let array):
                    if let key = Int.init(key) {
                        if let child = array.getOrNil(atIndex: key) {
                            return child.find(keyPath: Array(keyPath[1...]))
                        } else {
                            return .failure("Index out of bounds. Index: \(key), Size: \(array.count)")
                        }
                    } else {
                        return .failure("Can't convert key token '\(key)' to Int")
                    }
            }
        } else {
            return .success(self)
        }
    }

    func dumpAllKeysRecursive(path: String, result: inout [String]) {
        result.append(path)
        switch self {
            case .scalar: break
            case .map(let map):
                for (key, value) in map {
                    let path = path == "." ? key : path + "." + key
                    value.dumpAllKeysRecursive(path: path, result: &result)
                }
            case .array(let array):
                for (index, value) in array.enumerated() {
                    let path = path == "." ? String(index) : path + "." + String(index)
                    value.dumpAllKeysRecursive(path: path, result: &result)
                }
        }
    }
}

func buildConfigMap() -> ConfigMapValue {
    let mode = config.modes.mapValues { (mode: Mode) -> ConfigMapValue in
        let binding: [String: ConfigMapValue] = mode.bindings.mapValues { binding in
            .array(binding.commands.map { .scalar(.string($0.args.description)) })
        }
        return .map(["binding": .map(binding)])
    }
    return .map(["mode": .map(mode)])
}

enum ConfigScalarValue: Encodable {
    case string(String)
    case int(Int)

    var describe: String {
        return switch self {
            case .string(let string): string
            case .int(let int): String(int)
        }
    }

    func encode(to encoder: Encoder) throws {
        let value: Encodable = switch self {
            case .string(let string): string
            case .int(let int): int
        }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

enum ConfigMapValue: Encodable {
    case scalar(ConfigScalarValue)
    case map([String: ConfigMapValue])
    case array([ConfigMapValue])

    func encode(to encoder: Encoder) throws {
        let value: Encodable = switch self {
            case .scalar(let scalar): scalar
            case .map(let map): map
            case .array(let array): array
        }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
