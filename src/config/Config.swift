import HotKey
import Common

let mainModeId = "main"
let defaultConfig = initDefaultConfig(parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!)))
var config: Config = defaultConfig

struct RawConfig: Copyable {
    var afterLoginCommand: [Command]?
    var afterStartupCommand: [Command]?
    var indentForNestedContainersWithTheSameOrientation: Int?
    var enableNormalizationFlattenContainers: Bool?
    var nonEmptyWorkspacesRootContainersLayoutOnStartup: StartupRootContainerLayout?
    var defaultRootContainerLayout: Layout?
    var defaultRootContainerOrientation: DefaultContainerOrientation?
    var startAtLogin: Bool?
    var accordionPadding: Int?
    var enableNormalizationOppositeOrientationForNestedContainers: Bool?

    var gaps: Gaps?
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]]?
    var modes: [String: Mode]?
    var onWindowDetected: [WindowDetectedCallback]?
}
struct Config {
    var afterLoginCommand: [Command]
    var afterStartupCommand: [Command]
    var indentForNestedContainersWithTheSameOrientation: Int
    var enableNormalizationFlattenContainers: Bool
    var nonEmptyWorkspacesRootContainersLayoutOnStartup: StartupRootContainerLayout
    var defaultRootContainerLayout: Layout
    var defaultRootContainerOrientation: DefaultContainerOrientation
    var startAtLogin: Bool
    var accordionPadding: Int
    var enableNormalizationOppositeOrientationForNestedContainers: Bool

    let gaps: Gaps
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]]
    let modes: [String: Mode]
    var onWindowDetected: [WindowDetectedCallback]

    var preservedWorkspaceNames: [String]
}

struct CallbackMatcher: Copyable {
    var appId: String?
    var appNameRegexSubstring: Regex<AnyRegexOutput>?
    var windowTitleRegexSubstring: Regex<AnyRegexOutput>?
    var duringAeroSpaceStartup: Bool?
}
struct WindowDetectedCallback {
    let matcher: CallbackMatcher
    let checkFurtherCallbacks: Bool
    let run: [any Command]
}

struct Gaps: Equatable {
    let inner: Inner
    let outer: Outer

    struct Inner: Equatable {
        let vertical: Int
        let horizontal: Int

        func get(_ orientation: Orientation) -> Int { orientation == .h ? horizontal : vertical }

        static var zero = Inner(vertical: 0, horizontal: 0)
    }

    struct Outer: Equatable {
        let left: Int
        let bottom: Int
        let top: Int
        let right: Int

        static var zero = Outer(left: 0, bottom: 0, top: 0, right: 0)
    }

    static var zero = Gaps(inner: .zero, outer: .zero)
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}

enum StartupRootContainerLayout: String, CaseIterable {
    case smart, tiles, accordion
}

struct Mode: Copyable {
    /// User visible name. Optional. todo drop it?
    var name: String?
    var bindings: [HotkeyBinding]

    static let zero = Mode(name: nil, bindings: [])

    func deactivate() {
        for binding in bindings {
            binding.deactivate()
        }
    }
}

class HotkeyBinding {
    let modifiers: NSEvent.ModifierFlags
    let key: Key
    let commands: [Command]
    private var hotKey: HotKey? = nil

    init(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ commands: [Command]) {
        self.modifiers = modifiers
        self.key = key
        self.commands = commands
    }

    func activate() {
        hotKey = HotKey(key: key, modifiers: modifiers, keyUpHandler: { [commands] in
            refreshSession {
                var subject = CommandSubject.focused
                commands.run(&subject)
            }
        })
    }

    func deactivate() {
        hotKey = nil
    }
}

private func initDefaultConfig(_ parsedConfig: (config: Config, errors: [TomlParseError])) -> Config {
    if !parsedConfig.errors.isEmpty {
        error("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}
