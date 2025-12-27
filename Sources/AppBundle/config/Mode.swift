import Common
import HotKey
import TOMLKit

struct Mode: ConvenienceCopyable, Equatable, Sendable {
    /// User visible name. Optional. todo drop it?
    var name: String? = nil
    /// Parent mode name for inheritance. Bindings from parent are inherited.
    var inherits: String? = nil
    /// App bundle ID for app-specific modes. When set, this mode activates automatically when the app is focused.
    var app: String? = nil
    /// List of key bindings to remove from inherited bindings. Keys pass through to the underlying app.
    var unbind: [String] = []
    var bindings: [String: HotkeyBinding] = [:]

    static let zero = Mode()
}

func parseModes(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> ([String: Mode], [String: String]) {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return ([:], [:])
    }
    var result: [String: Mode] = [:]

    for (key, value) in rawTable {
        result[key] = parseMode(value, backtrace + .key(key), &errors, mapping)
    }

    if !result.keys.contains(mainModeId) {
        errors += [.semantic(backtrace, "Please specify '\(mainModeId)' mode")]
    }

    // Validate inheritance chains - detect cycles and undefined parents
    var modesWithInheritanceErrors: Set<String> = []
    for (modeName, mode) in result {
        if mode.inherits != nil {
            if !validateInheritanceChain(modeName, result, backtrace, &errors) {
                modesWithInheritanceErrors.insert(modeName)
            }
        }
    }

    // Flatten bindings - each mode gets its own + inherited bindings
    // Skip modes with inheritance errors to avoid infinite recursion
    flattenModeBindings(&result, skipping: modesWithInheritanceErrors)

    // Build appModes mapping by scanning all modes for app property
    var appModes: [String: String] = [:] // bundleId -> modeName
    for (modeName, mode) in result {
        if let bundleId = mode.app {
            appModes[bundleId] = modeName
        }
    }

    return (result, appModes)
}

/// Returns true if the inheritance chain is valid, false if there's an error
private func validateInheritanceChain(_ modeName: String, _ modes: [String: Mode], _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Bool {
    var visited: Set<String> = []
    var current: String? = modeName

    while let name = current {
        if visited.contains(name) {
            let chain = Array(visited).joined(separator: " -> ")
            errors += [.semantic(backtrace + .key(modeName), "Circular inheritance detected: \(chain) -> \(name)")]
            return false
        }
        visited.insert(name)
        current = modes[name]?.inherits

        if let parent = current, modes[parent] == nil {
            errors += [.semantic(backtrace + .key(modeName), "Mode '\(modeName)' inherits from undefined mode '\(parent)'")]
            return false
        }
    }
    return true
}

private func flattenModeBindings(_ modes: inout [String: Mode], skipping: Set<String> = []) {
    // Create a cache to avoid recomputing for modes that are parents of multiple children
    var resolvedCache: [String: [String: HotkeyBinding]] = [:]

    // First, compute all resolved bindings into a separate dictionary to avoid overlapping access
    var resolvedBindings: [String: [String: HotkeyBinding]] = [:]
    for modeName in modes.keys where !skipping.contains(modeName) {
        resolvedBindings[modeName] = resolveBindings(modeName, modes, &resolvedCache)
    }

    // Then update the modes with the resolved bindings
    for (modeName, bindings) in resolvedBindings {
        modes[modeName]?.bindings = bindings
    }
}

private func resolveBindings(_ modeName: String, _ modes: [String: Mode], _ cache: inout [String: [String: HotkeyBinding]]) -> [String: HotkeyBinding] {
    if let cached = cache[modeName] {
        return cached
    }

    guard let mode = modes[modeName] else { return [:] }

    // Start with parent bindings (if any)
    var resolved: [String: HotkeyBinding] = [:]
    if let parentName = mode.inherits {
        resolved = resolveBindings(parentName, modes, &cache)
    }

    // Remove unbound keys from inherited bindings
    for key in mode.unbind {
        resolved.removeValue(forKey: key)
    }

    // Override with this mode's bindings
    for (key, binding) in mode.bindings {
        resolved[key] = binding
    }

    cache[modeName] = resolved
    return resolved
}

func parseMode(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> Mode {
    guard let rawTable: TOMLTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return .zero
    }

    var result: Mode = .zero
    for (key, value) in rawTable {
        let backtrace = backtrace + .key(key)
        switch key {
            case "binding":
                result.bindings = parseBindings(value, backtrace, &errors, mapping)
            case "inherits":
                if let inherits = value.string {
                    result.inherits = inherits
                } else {
                    errors += [expectedActualTypeError(expected: .string, actual: value.type, backtrace)]
                }
            case "app":
                if let app = value.string {
                    result.app = app
                } else {
                    errors += [expectedActualTypeError(expected: .string, actual: value.type, backtrace)]
                }
            case "unbind":
                if let array = value.array {
                    for item in array {
                        if let key = item.string {
                            result.unbind.append(key)
                        } else {
                            errors += [expectedActualTypeError(expected: .string, actual: item.type, backtrace)]
                        }
                    }
                } else {
                    errors += [expectedActualTypeError(expected: .array, actual: value.type, backtrace)]
                }
            default:
                errors += [unknownKeyError(backtrace)]
        }
    }
    return result
}
