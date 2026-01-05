import AppKit
import Common
import Foundation
import TOMLKit

@MainActor private var keyboardMonitor: KeyboardMonitor?
@MainActor private var hotkeys: [UInt32: [HotkeyBinding]] = [:]

private let genericModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]

@MainActor func resetHotKeys() {
    hotkeys = [:]
    keyboardMonitor = KeyboardMonitor() { event in
        let flags = event.flags.intersection(genericModifiers)
        guard let bindings = hotkeys[event.keyCode] else { return false }

        if let binding = bindings.first(where: { $0.modifiers == flags }) {
            Task {
                try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
                    _ = try await binding.commands.runCmdSeq(.defaultEnv, .emptyStdin)
                }
            }
            return true
        }
        return false
    }
}

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode(_ targetMode: String?) async throws {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    hotkeys = [:]
    for binding in targetBindings.values {
        hotkeys[binding.keyCode, default: []].append(binding)
    }
    let oldMode = activeMode
    activeMode = targetMode
    if oldMode != targetMode && !config.onModeChanged.isEmpty {
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.onModeChanged, token) {
            _ = try await config.onModeChanged.runCmdSeq(.defaultEnv, .emptyStdin)
        }
    }
}

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: CGEventFlags
    let keyCode: UInt32
    let commands: [any Command]
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ modifiers: CGEventFlags, _ keyCode: UInt32, _ commands: [any Command], descriptionWithKeyNotation: String) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyCode = modifiers.isEmpty
            ? keyCode.keyCodeToString()
            : modifiers.toString() + "-" + keyCode.keyCodeToString()
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: UInt32]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .flatMap { modifiers, key -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
                    HotkeyBinding(modifiers, key, $0, descriptionWithKeyNotation: binding)
                }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                errors.append(.semantic(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: UInt32]) -> ParsedToml<(CGEventFlags, UInt32)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<CGEventFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { CGEventFlags($0) }
    let key: ParsedToml<UInt32> = rawKeys.last.flatMap { mapping[String($0)] }
        .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedToml<(CGEventFlags, UInt32)> in
        key.flatMap { key -> ParsedToml<(CGEventFlags, UInt32)> in
            .success((modifiers, key))
        }
    }
}
