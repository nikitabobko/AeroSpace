import HotKey
import Common

let mainModeId = "main"
let defaultConfig = initDefaultConfig(parseConfig(try! String(contentsOf: Bundle.main.url(forResource: "default-config", withExtension: "toml")!)))
var config: Config = defaultConfig

struct RawConfig: Copyable {
    var afterLoginCommand: [any Command]?
    var afterStartupCommand: [any Command]?
    var indentForNestedContainersWithTheSameOrientation: Int?
    var enableNormalizationFlattenContainers: Bool?
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void?
    var defaultRootContainerLayout: Layout?
    var defaultRootContainerOrientation: DefaultContainerOrientation?
    var startAtLogin: Bool?
    var accordionPadding: Int?
    var enableNormalizationOppositeOrientationForNestedContainers: Bool?
    var execOnWorkspaceChange: [String]?

    var gaps: Gaps?
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]]?
    var modes: [String: Mode]?
    var onWindowDetected: [WindowDetectedCallback]?
}
struct Config {
    var afterLoginCommand: [any Command]
    var afterStartupCommand: [any Command]
    var indentForNestedContainersWithTheSameOrientation: Int
    var enableNormalizationFlattenContainers: Bool
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void
    var defaultRootContainerLayout: Layout
    var defaultRootContainerOrientation: DefaultContainerOrientation
    var startAtLogin: Bool
    var accordionPadding: Int
    var enableNormalizationOppositeOrientationForNestedContainers: Bool
    var execOnWorkspaceChange: [String]

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

struct Gaps {
    let inner: Inner
    let outer: Outer

    struct Inner {
        let vertical: DynamicConfigValue<Int>
        let horizontal: DynamicConfigValue<Int>

        static var zero = Inner(vertical: 0, horizontal: 0)

        init(vertical: Int, horizontal: Int) {
            self.vertical = .constant(vertical)
            self.horizontal = .constant(horizontal)
        }

        init(vertical: DynamicConfigValue<Int>, horizontal: DynamicConfigValue<Int>) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
    }

    struct Outer {
        let left: DynamicConfigValue<Int>
        let bottom: DynamicConfigValue<Int>
        let top: DynamicConfigValue<Int>
        let right: DynamicConfigValue<Int>

        static var zero = Outer(left: 0, bottom: 0, top: 0, right: 0)

        init(left: Int, bottom: Int, top: Int, right: Int) {
            self.left = .constant(left)
            self.bottom = .constant(bottom)
            self.top = .constant(top)
            self.right = .constant(right)
        }

        init(left: DynamicConfigValue<Int>, bottom: DynamicConfigValue<Int>, top: DynamicConfigValue<Int>, right: DynamicConfigValue<Int>) {
            self.left = left
            self.bottom = bottom
            self.top = top
            self.right = right
        }
    }

    static var zero = Gaps(inner: .zero, outer: .zero)
}

struct ResolvedGaps {
    let inner: Inner
    let outer: Outer

    struct Inner {
        let vertical: Int
        let horizontal: Int

        func get(_ orientation: Orientation) -> Int {
            orientation == .h ? horizontal : vertical
        }
    }

    struct Outer {
        let left: Int
        let bottom: Int
        let top: Int
        let right: Int
    }

    init(gaps: Gaps, monitor: any Monitor) {
        inner = .init(
            vertical: gaps.inner.vertical.getValue(for: monitor),
            horizontal: gaps.inner.horizontal.getValue(for: monitor)
        )

        outer = .init(
            left: gaps.outer.left.getValue(for: monitor),
            bottom: gaps.outer.bottom.getValue(for: monitor),
            top: gaps.outer.top.getValue(for: monitor),
            right: gaps.outer.right.getValue(for: monitor)
        )
    }
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
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
    let commands: [any Command]
    private var hotKey: HotKey? = nil

    init(_ modifiers: NSEvent.ModifierFlags, _ key: Key, _ commands: [any Command]) {
        self.modifiers = modifiers
        self.key = key
        self.commands = commands
    }

    func activate() {
        hotKey = HotKey(key: key, modifiers: modifiers, keyUpHandler: { [commands] in
            refreshSession(forceFocus: true) {
                _ = commands.run(.focused)
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
