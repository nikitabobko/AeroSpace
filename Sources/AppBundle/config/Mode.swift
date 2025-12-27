import Common
import HotKey
import OrderedCollections

struct Mode: ConvenienceCopyable, Equatable, Sendable {
    var inherits: String? = nil
    var app: String? = nil
    var unbind: [String] = []
    var bindings: [String: HotkeyBinding] = [:]

    static let zero = Mode()
}

func parseModes(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError], _ mapping: [String: Key]) -> ([String: Mode], [String: String]) {
    guard let rawTable = raw.asDictOrNil else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.tomlType, backtrace)]
        return ([:], [:])
    }
    var result: [String: Mode] = [:]

    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors, mapping)
    }

    if !result.keys.contains(mainModeId) {
        errors += [.semantic(backtrace, "Please specify '\(mainModeId)' mode")]
    }

    var modesWithInheritanceErrors: Set<String> = []
    for (modeName, mode) in result {
        if mode.inherits != nil {
            if !validateInheritanceChain(modeName, result, backtrace, &errors) {
                modesWithInheritanceErrors.insert(modeName)
            }
        }
    }

    flattenModeBindings(&result, skipping: modesWithInheritanceErrors)

    var appModes: [String: String] = [:]
    for (modeName, mode) in result {
        if let bundleId = mode.app {
            appModes[bundleId] = modeName
        }
    }

    return (result, appModes)
}

private func validateInheritanceChain(_ modeName: String, _ modes: [String: Mode], _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> Bool {
    var visited: OrderedSet<String> = []
    var current: String? = modeName

    while let name = current {
        if visited.contains(name) {
            let chain = visited.joined(separator: " -> ")
            errors += [.semantic(backtrace + .key(modeName), "Circular inheritance detected: \(chain) -> \(name)")]
            return false
        }
        visited.append(name)
        current = modes[name]?.inherits

        if let parent = current, modes[parent] == nil {
            errors += [.semantic(backtrace + .key(modeName), "Mode '\(modeName)' inherits from undefined mode '\(parent)'")]
            return false
        }
    }
    return true
}

private func flattenModeBindings(_ modes: inout [String: Mode], skipping: Set<String> = []) {
    var resolvedCache: [String: [String: HotkeyBinding]] = [:]

    var resolvedBindings: [String: [String: HotkeyBinding]] = [:]
    for modeName in modes.keys where !skipping.contains(modeName) {
        resolvedBindings[modeName] = resolveBindings(modeName, modes, &resolvedCache)
    }

    for (modeName, bindings) in resolvedBindings {
        modes[modeName]?.bindings = bindings
    }
}

private func resolveBindings(_ modeName: String, _ modes: [String: Mode], _ cache: inout [String: [String: HotkeyBinding]]) -> [String: HotkeyBinding] {
    if let cached = cache[modeName] {
        return cached
    }

    guard let mode = modes[modeName] else { return [:] }

    var resolved: [String: HotkeyBinding] = [:]
    if let parentName = mode.inherits {
        resolved = resolveBindings(parentName, modes, &cache)
    }

    for key in mode.unbind {
        resolved.removeValue(forKey: key)
    }

    for (key, binding) in mode.bindings {
        resolved[key] = binding
    }

    cache[modeName] = resolved
    return resolved
}

func parseMode(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError], _ mapping: [String: Key]) -> Mode {
    let modeParser: [String: any ParserProtocol<Mode>] = [
        "binding": Parser(\.bindings) { raw, backtrace, errors in parseBindings(raw, backtrace, &errors, mapping) },
        "inherits": Parser(\.inherits) { parseString($0, $1).map(String?.some) },
        "app": Parser(\.app) { parseString($0, $1).map(String?.some) },
        "unbind": Parser(\.unbind, parseArrayOfStrings),
    ]
    return parseTable(raw, .zero, modeParser, backtrace, &errors)
}
