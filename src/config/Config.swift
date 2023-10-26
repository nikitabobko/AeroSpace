import HotKey

let mainModeId = "main" // todo rename to "default"
let defaultConfig =
    parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!))
        .also {
            if !$0.log.isEmpty {
                error("Can't parse default config: \($0.log)")
            }
        }
        .value
var config: Config = defaultConfig

struct Config {
    var afterStartupCommand: Command
    var afterLoginCommand: Command
    var indentForNestedContainersWithTheSameOrientation: Int
    var enableNormalizationFlattenContainers: Bool
    var floatingWindowsOnTop: Bool
    var mainLayout: ConfigLayout // todo rename to defaultLayout
    var startAtLogin: Bool
    var accordionPadding: Int
    var enableNormalizationOppositeOrientationForNestedContainers: Bool

    let modes: [String: Mode]
    var preservedWorkspaceNames: [String]
}

enum ConfigLayout: String {
    case main
    case h_accordion, v_accordion, h_list, v_list
    case tiling, floating, sticky // todo can sticky windows be tiling?
}

struct Mode: Copyable {
    /// User visible name. Optional. todo drop it?
    var name: String?
    var bindings: [HotkeyBinding]

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
