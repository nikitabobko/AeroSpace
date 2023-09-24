import HotKey

let mainModeId = "main" // todo rename to "default"
let defaultConfig =
    parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!))
var config: Config = defaultConfig

struct Config {
    var afterStartupCommand: Command
    var usePaddingForNestedContainersWithTheSameOrientation: Bool // todo
    var autoFlattenContainers: Bool
    var floatingWindowsOnTop: Bool
    var mainLayout: ConfigLayout // todo rename to defaultLayout
    var focusWrapping: FocusWrapping

    let modes: [String: Mode]
    var workspaceNames: [String]
    var mainMode: Mode { modes[mainModeId] ?? errorT("Invalid config. main mode must be always presented") }
}

enum FocusWrapping: String { // todo think about mental model
    case disable
    case workspace
    case container
}

enum ConfigLayout: String {
    case main
    case h_accordion, v_accordion, h_list, v_list
    case tiling, floating, sticky // todo can sticky windows be tiling?
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
        hotKey = HotKey(key: key, modifiers: modifiers, keyUpHandler: { [command] in
            Task { await command.run() }
        })
    }

    func deactivate() {
        hotKey = nil
    }
}
