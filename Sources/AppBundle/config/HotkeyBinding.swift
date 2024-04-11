import AppKit
import Foundation
import HotKey

private var hotkeys: [String: HotKey] = [:]

func resetHotKeys() {
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

var activeMode: String? = mainModeId
func activateMode(_ targetMode: String?) {
    let targetBindings = targetMode.flatMap { config.modes[$0] }?.bindings ?? [:]
    for binding in targetBindings.values where !hotkeys.keys.contains(binding.binding) {
        hotkeys[binding.binding] = HotKey(key: binding.key, modifiers: binding.modifiers, keyUpHandler: {
            if let activeMode {
                refreshSession(forceFocus: true) {
                    _ = config.modes[activeMode]?.bindings[binding.binding]?.commands.run(.focused)
                }
            }
        })
    }
    for (binding, key) in hotkeys {
        if targetBindings.keys.contains(binding) {
            key.isEnabled = true
        } else {
            key.isEnabled = false
        }
    }
    activeMode = targetMode
}

struct HotkeyBinding {
    let modifiers: NSEvent.ModifierFlags
    let key: Key
    let commands: [any Command]
    let binding: String

    init(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ commands: [any Command]) {
        self.modifiers = modifiers
        self.key = key
        self.commands = commands
        self.binding = modifiers.isEmpty ? key.description : modifiers.toString() + "-\(key)"
    }
}
