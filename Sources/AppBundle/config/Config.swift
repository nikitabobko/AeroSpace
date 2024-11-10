import AppKit
import Common
import HotKey

func getDefaultConfigUrlFromProject() -> URL {
    var url = URL(filePath: #file)
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    let projectRoot: URL = url
    return projectRoot.appending(component: "docs/config-examples/default-config.toml")
}

public var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
let defaultConfig: Config = {
    let parsedConfig = parseConfig(try! String(contentsOf: defaultConfigUrl))
    if !parsedConfig.errors.isEmpty {
        error("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
public var config: Config = defaultConfig
var configUrl: URL = defaultConfigUrl

public struct Config: Copyable {
    var afterLoginCommand: [any Command] = []
    var afterStartupCommand: [any Command] = []
    var _indentForNestedContainersWithTheSameOrientation: Void = ()
    var enableNormalizationFlattenContainers: Bool = true
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var defaultRootContainerLayout: Layout = .tiles
    var defaultRootContainerOrientation: DefaultContainerOrientation = .auto
    var startAtLogin: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var accordionPadding: Int = 30
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var execOnWorkspaceChange: [String] = [] // todo deprecate
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var onFocusChanged: [any Command] = []
    // var onFocusedWorkspaceChanged: [any Command] = []
    var onFocusedMonitorChanged: [any Command] = []

    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []

    var preservedWorkspaceNames: [String] = []
    
    
    public var fontFamily: String = ""
    public var fontSize: Double = 13.0
    
    public var workSpaceIndicatorStyle: WorkSpaceIndicatorStyle = .icon
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}

public enum WorkSpaceIndicatorStyle: String {
    case icon, horizontal_full, horizontal_min
}
