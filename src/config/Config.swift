import HotKey

struct Config {
    let afterStartupCommand: Command
    let usePaddingForNestedContainersWithTheSameOrientation: Bool
    let autoFlattenContainers: Bool
    let floatingWindowsOnTop: Bool
    let modes: [String: Mode]
}

struct Mode {
    /// User visible name. Optional. todo drop it?
    let name: String?
    let bindings: [HotkeyBinding]

    func activate() {
        for binding in bindings {
            binding.activate()
        }
    }

    func deactivate() {
        for binding in bindings {
            binding.deactivate()
        }
    }
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
