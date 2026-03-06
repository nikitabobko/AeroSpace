import Foundation

public enum ServerEventType: String, Codable, CaseIterable, Sendable {
    case focusChanged = "focus-changed"
    case focusedMonitorChanged = "focused-monitor-changed"
    case workspaceChanged = "focused-workspace-changed"
    case modeChanged = "mode-changed"
    case windowDetected = "window-detected"
    case bindingTriggered = "binding-triggered"
}

public struct ServerEvent: Codable, Sendable {
    public let event: ServerEventType
    public var windowId: UInt32?
    public var workspace: String?
    public var prevWorkspace: String?
    public var monitorId: Int?
    public var mode: String?
    public var appBundleId: String?
    public var appName: String?
    public var windowTitle: String?
    public var binding: String?

    private init(
        event: ServerEventType,
        windowId: UInt32? = nil,
        workspace: String? = nil,
        prevWorkspace: String? = nil,
        monitorId: Int? = nil,
        mode: String? = nil,
        appBundleId: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        binding: String? = nil,
    ) {
        self.event = event
        self.windowId = windowId
        self.workspace = workspace
        self.prevWorkspace = prevWorkspace
        self.monitorId = monitorId
        self.mode = mode
        self.appBundleId = appBundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.binding = binding
    }

    public static func focusChanged(windowId: UInt32?, workspace: String, monitorId: Int) -> ServerEvent {
        ServerEvent(event: .focusChanged, windowId: windowId, workspace: workspace, monitorId: monitorId)
    }

    public static func focusedMonitorChanged(workspace: String, monitorId: Int) -> ServerEvent {
        ServerEvent(event: .focusedMonitorChanged, workspace: workspace, monitorId: monitorId)
    }

    public static func workspaceChanged(workspace: String, prevWorkspace: String) -> ServerEvent {
        ServerEvent(event: .workspaceChanged, workspace: workspace, prevWorkspace: prevWorkspace)
    }

    public static func modeChanged(mode: String?) -> ServerEvent {
        ServerEvent(event: .modeChanged, mode: mode)
    }

    public static func windowDetected(windowId: UInt32, workspace: String?, appBundleId: String?, appName: String?, windowTitle: String?) -> ServerEvent {
        ServerEvent(event: .windowDetected, windowId: windowId, workspace: workspace, appBundleId: appBundleId, appName: appName, windowTitle: windowTitle)
    }

    public static func bindingTriggered(mode: String, binding: String) -> ServerEvent {
        ServerEvent(event: .bindingTriggered, mode: mode, binding: binding)
    }
}

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public var stderr: String
    public let serverVersionAndHash: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = "",
        serverVersionAndHash: String,
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.serverVersionAndHash = serverVersionAndHash
    }
}

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ClientRequest: Codable, Sendable, ConvenienceCopyable, Equatable {
    public var command: String? = nil // Unused. keep it for API compatibility with old servers for a couple of version

    public let args: [String]
    public let stdin: String

    // Double Optional to encode explicit null into JSON
    public var windowId: UInt32??  // Please forward AEROSPACE_WINDOW_ID env variable here
    public var workspace: String?? // Please forward AEROSPACE_WORKSPACE env variable here

    public init(
        args: [String],
        stdin: String,
        windowId: UInt32?,
        workspace: String?,
    ) {
        self.args = args
        self.stdin = stdin
        self.windowId = .some(windowId)
        self.workspace = .some(workspace)
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }

    enum CodingKeys: String, CodingKey {
        case args
        case stdin
        case windowId
        case workspace
    }

    public init(from decoder: any Decoder) throws {
        let data = try ClientRequestData.init(from: decoder)
        var raw = ClientRequest(
            args: data.args,
            stdin: data.stdin,
            windowId: data.windowId.flatMap { $0 },
            workspace: data.workspace.flatMap { $0 },
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if !container.contains(.windowId) { raw.windowId = nil }
        if !container.contains(.workspace) { raw.workspace = nil }
        self = raw
    }
}

private struct ClientRequestData: Codable, Sendable {
    public var args: [String]
    public var stdin: String
    public var windowId: UInt32??
    public var workspace: String??
}
