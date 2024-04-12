import AppKit
import HotKey
import Common

let mainModeId = "main"
var defaultConfigUrl: URL { Bundle.main.url(forResource: "default-config", withExtension: "toml")! }
let defaultConfig: Config = {
    let defaultConfig: URL
    if isUnitTest {
        var url = URL(filePath: #file)
        while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
            url.deleteLastPathComponent()
        }
        let projectRoot: URL = url
        defaultConfig = projectRoot.appending(component: "docs/config-examples/default-config.toml")
    } else {
        defaultConfig = defaultConfigUrl
    }
    let parsedConfig = parseConfig(try! String(contentsOf: defaultConfig))
    if !parsedConfig.errors.isEmpty {
        error("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
var config: Config = defaultConfig

struct Config: Copyable {
    var afterLoginCommand: [any Command] = []
    var afterStartupCommand: [any Command] = []
    var indentForNestedContainersWithTheSameOrientation: Void = ()
    var enableNormalizationFlattenContainers: Bool = true
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var defaultRootContainerLayout: Layout = .tiles
    var defaultRootContainerOrientation: DefaultContainerOrientation = .auto
    var startAtLogin: Bool = false
    var accordionPadding: Int = 30
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var execOnWorkspaceChange: [String] = []
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []

    var preservedWorkspaceNames: [String] = []
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}
