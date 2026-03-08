// periphery:ignore:all - false positive unused warning. The var properties are serialized to JSON
import Common

public struct ServerEvent: Codable, Sendable {
    private let _event: ServerEventType
    private var windowId: UInt32?
    private var workspace: String?
    private var prevWorkspace: String?
    private var monitorId: Int? // 1-based
    private var appBundleId: String?
    private var appName: String?

    private var mode: String?
    private var binding: String?

    public var eventType: ServerEventType { _event }

    public static func focusChanged(windowId: UInt32?, workspace: String) -> ServerEvent {
        ServerEvent(_event: .focusChanged, windowId: windowId, workspace: workspace)
    }

    public static func focusedMonitorChanged(workspace: String, monitorId_oneBased: Int) -> ServerEvent {
        ServerEvent(_event: .focusedMonitorChanged, workspace: workspace, monitorId: monitorId_oneBased)
    }

    public static func workspaceChanged(workspace: String, prevWorkspace: String) -> ServerEvent {
        ServerEvent(_event: .workspaceChanged, workspace: workspace, prevWorkspace: prevWorkspace)
    }

    public static func modeChanged(mode: String?) -> ServerEvent {
        ServerEvent(_event: .modeChanged, mode: mode)
    }

    public static func windowDetected(windowId: UInt32, workspace: String?, appBundleId: String?, appName: String?) -> ServerEvent {
        ServerEvent(_event: .windowDetected, windowId: windowId, workspace: workspace, appBundleId: appBundleId, appName: appName)
    }

    public static func bindingTriggered(mode: String, binding: String) -> ServerEvent {
        ServerEvent(_event: .bindingTriggered, mode: mode, binding: binding)
    }
}
