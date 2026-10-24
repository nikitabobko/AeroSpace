import AppKit
import Common
import Foundation
import HotKey

@MainActor private var hotkeys: [String: HotKey] = [:]

@MainActor func resetHotKeys() {
    // Explicitly unregister all hotkeys. We cannot always rely on destruction of the HotKey object to trigger
    // unregistration because we might be running inside a hotkey handler that is keeping its HotKey object alive.
    for (_, key) in hotkeys {
        key.isEnabled = false
    }
    hotkeys = [:]
}

extension HotKey {
    var isEnabled: Bool {
        get { !isPaused }
        set {
            if isEnabled != newValue {
                isPaused = !newValue
            }
        }
    }
}

@MainActor var activeMode: String? = mainModeId
@MainActor func activateMode_nonCancellable(_ targetMode: String?) async {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    for binding in targetBindings.values where !hotkeys.keys.contains(binding.descriptionWithKeyCode) {
        hotkeys[binding.descriptionWithKeyCode] = HotKey(key: binding.keyCode, modifiers: binding.modifiers, keyDownHandler: {
            Task.startUnstructured { @MainActor in
                if let activeMode {
                    broadcastEvent(.bindingTriggered(
                        mode: activeMode,
                        binding: binding.descriptionWithKeyNotation,
                    ))
                    guard let commands = config.modes[activeMode]?.bindings[binding.descriptionWithKeyCode]?.commands else { return }
                    let flat = commands.flatten()
                    if !isUnitTest, flat.count == 1, let execCmd = flat.first as? ExecAndForgetCommand,
                       try await handleFastHotkeyExecIfPossible(execCmd.args.bashScript)
                    {
                        return
                    }
                    if !isUnitTest && flat.allSatisfy({ $0 is ExecAndForgetCommand }) {
                        guard RunSessionGuard.isServerEnabled != nil else { return }
                        _ = await commands.run(.defaultEnv, .emptyStdin)
                    } else {
                        try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie()) { () throws in
                            _ = await commands.run(.defaultEnv, .emptyStdin)
                        }
                    }
                }
            }
        })
    }
    for (binding, key) in hotkeys {
        key.isEnabled = targetBindings.keys.contains(binding)
    }
    let oldMode = activeMode
    activeMode = targetMode
    if oldMode != targetMode {
        broadcastEvent(.modeChanged(mode: targetMode))
        _ = await config.onModeChanged.run(.defaultEnv, .emptyStdin)
    }
}

struct HotkeyBinding: Equatable, Sendable {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: Key
    let commands: Shell<any Command>
    let descriptionWithKeyCode: String
    let descriptionWithKeyNotation: String

    init(_ modifiers: NSEvent.ModifierFlags, _ keyCode: Key, _ commands: Shell<any Command>, descriptionWithKeyNotation: String) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyCode = modifiers.isEmpty
            ? keyCode.toString()
            : modifiers.toString() + "-" + keyCode.toString()
        self.descriptionWithKeyNotation = descriptionWithKeyNotation
    }

    static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            lhs.commands.strictEquals(rhs.commands)
    }
}

func parseBindings(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext, _ mapping: [String: Key]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (binding, rawCommand): (String, OrderedJson) in rawTable {
        let backtrace = backtrace + .key(binding)
        let binding = parseBinding(binding, backtrace, mapping)
            .map { modifiers, key -> HotkeyBinding in
                let commands = parseShellOfCommandsForConfig(rawCommand, backtrace, &c)
                return HotkeyBinding(modifiers, key, commands, descriptionWithKeyNotation: binding)
            }
            .getOrNil(appendErrorTo: &c.errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                c.errors.append(.init(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: ConfigBacktrace, _ mapping: [String: Key]) -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ResOrConfigParseDiagnostic<NSEvent.ModifierFlags> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].toResult(.init(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { NSEvent.ModifierFlags($0) }
    let key: ResOrConfigParseDiagnostic<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .toResult(.init(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Key)> in
        key.flatMap { key -> ResOrConfigParseDiagnostic<(NSEvent.ModifierFlags, Key)> in
            .success((modifiers, key))
        }
    }
}

@MainActor
private func resolveWorkspaceSlot(_ baseName: String) -> String {
    let candidates = Array(config.persistentWorkspaces) + Workspace.all.map(\.name)
    if let labeled = candidates.first(where: { $0.hasPrefix("\(baseName)-") || $0.hasPrefix("\(baseName)_") }) {
        return labeled
    }
    return baseName
}

private func tierForWorkspaceName(_ name: String) -> String {
    if name.hasPrefix("⌃⌥") { return "set3" }
    if name.hasPrefix("⌥") { return "set2" }
    if name.hasPrefix("fn") { return "set4" }
    return "set1"
}

private func resolveSelectorTarget(_ target: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let activeEnv = ProcessInfo.processInfo.environment["ACTIVE_ENV_SET"] ?? "0"
    for envId in [activeEnv, "0"] {
        let valUrl = home.appending(path: ".env_set/\(envId)/.\(target).cfg.val")
        if let content = try? String(contentsOf: valUrl, encoding: .utf8).trim(),
           !content.isEmpty, content != "none"
        {
            return content
        }
    }
    return target
}

@MainActor
private func handleFastHotkeyExecIfPossible(_ bashScript: String) async throws -> Bool {
    guard let guardToken = RunSessionGuard.isServerEnabled else { return false }
    let trimmed = bashScript.trim()
    if let range = trimmed.range(of: "focus_app.py ") {
        let rawTarget = String(trimmed[range.upperBound...]).trim()
        let resolved = resolveSelectorTarget(rawTarget).lowercased()
        if resolved == "iterm" || resolved == "iterm2" {
            let matching = focus.workspace.allLeafWindowsRecursive.filter {
                $0.app.rawAppBundleId == "com.googlecode.iterm2"
            }
            if !matching.isEmpty {
                let targetWin: Window
                if matching.count == 1 {
                    targetWin = matching[0]
                } else if let focusedId = focus.windowOrNil?.windowId,
                          let idx = matching.firstIndex(where: { $0.windowId == focusedId })
                {
                    targetWin = matching[(idx + 1) % matching.count]
                } else {
                    targetWin = matching[0]
                }
                try await runLightSession(.menuBarButton, guardToken) {
                    _ = targetWin.focusWindow()
                }
                return true
            }
            for app in MacApp.allAppsMap.values where app.rawAppBundleId == "com.googlecode.iterm2" {
                app.markExternallyUnhiddenOrActivated()
                app.unhideIfHiddenByAeroSpace(forceIfHidden: true)
            }
            Task.detached {
                let proc = Process()
                proc.executableURL = URL(filePath: "/usr/bin/osascript")
                proc.arguments = ["-e", "tell application \"iTerm2\"\ncreate window with default profile\nactivate\nend tell"]
                try? proc.run()
            }
            return true
        }
    }
    if let range = trimmed.range(of: "switch_workspace.py switch ") {
        let baseName = String(trimmed[range.upperBound...]).trim()
        guard !baseName.isEmpty else { return false }
        let targetWs = resolveWorkspaceSlot(baseName)
        let tier = tierForWorkspaceName(baseName)
        Task.detached {
            let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/aerospace/.active_tier")
            try? tier.write(to: url, atomically: true, encoding: .utf8)
        }
        try await runLightSession(.menuBarButton, guardToken) {
            _ = Workspace.get(byName: targetWs).focusWorkspace()
        }
        return true
    }
    if trimmed.hasSuffix("workspace_prev_next.py prev") || trimmed.hasSuffix("workspace_prev_next.py next") {
        let isNext = trimmed.hasSuffix(" next")
        let orderedPrefixes = ["fn", "⌥", "", "⌃⌥"]
        let orderedSlots: [String] = orderedPrefixes.flatMap { prefix in
            (1 ... 10).map { resolveWorkspaceSlot("\(prefix)\($0)") }
        }
        let currentName = focus.workspace.name
        guard let currentIdx = orderedSlots.firstIndex(of: currentName) else { return false }
        let targetIdx = isNext ? currentIdx + 1 : currentIdx - 1
        guard targetIdx >= 0 && targetIdx < orderedSlots.count else { return true }
        let targetWs = orderedSlots[targetIdx]
        let tier = tierForWorkspaceName(targetWs)
        Task.detached {
            let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/aerospace/.active_tier")
            try? tier.write(to: url, atomically: true, encoding: .utf8)
        }
        try await runLightSession(.menuBarButton, guardToken) {
            _ = Workspace.get(byName: targetWs).focusWorkspace()
        }
        return true
    }
    return false
}
