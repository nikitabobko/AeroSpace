import AppKit
import Common

struct ListTreeCommand: Command {
    let args: ListTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let focusedWorkspace = focus.workspace
        var monitorNodes: [MonitorNode] = []

        for monitor in sortedMonitors {
            let monitorPoint = monitor.rect.topLeftCorner
            let monitorWorkspaces = Workspace.all
                .filter { $0.workspaceMonitor.rect.topLeftCorner == monitorPoint }

            var workspaceNodes: [WorkspaceNode] = []
            for workspace in monitorWorkspaces {
                var windowNodes: [WindowNode] = []
                for window in workspace.allLeafWindowsRecursive {
                    guard window.isBound else { continue }
                    let title = try await window.title
                    windowNodes.append(WindowNode(
                        window_id: window.windowId,
                        app_name: window.app.name ?? "",
                        app_bundle_id: window.app.rawAppBundleId,
                        window_title: title
                    ))
                }
                windowNodes.sort { ($0.app_name, $0.window_title) < ($1.app_name, $1.window_title) }

                workspaceNodes.append(WorkspaceNode(
                    workspace: workspace.name,
                    workspace_is_focused: workspace == focusedWorkspace,
                    workspace_is_visible: workspace.isVisible,
                    windows: windowNodes
                ))
            }

            monitorNodes.append(MonitorNode(
                monitor_id: monitor.monitorId_oneBased ?? 0,
                monitor_name: monitor.name,
                monitor_is_main: monitor.isMain,
                monitor_width: Int(monitor.width),
                monitor_height: Int(monitor.height),
                workspaces: workspaceNodes
            ))
        }

        guard let json = JSONEncoder.aeroSpaceDefault.encodeToString(monitorNodes) else {
            return io.err("Failed to encode tree to JSON")
        }
        return io.out(json)
    }
}

private struct MonitorNode: Encodable {
    let monitor_id: Int
    let monitor_name: String
    let monitor_is_main: Bool
    let monitor_width: Int
    let monitor_height: Int
    let workspaces: [WorkspaceNode]

    enum CodingKeys: String, CodingKey {
        case monitor_id = "monitor-id"
        case monitor_name = "monitor-name"
        case monitor_is_main = "monitor-is-main"
        case monitor_width = "monitor-width"
        case monitor_height = "monitor-height"
        case workspaces
    }
}

private struct WorkspaceNode: Encodable {
    let workspace: String
    let workspace_is_focused: Bool
    let workspace_is_visible: Bool
    let windows: [WindowNode]

    enum CodingKeys: String, CodingKey {
        case workspace
        case workspace_is_focused = "workspace-is-focused"
        case workspace_is_visible = "workspace-is-visible"
        case windows
    }
}

private struct WindowNode: Encodable {
    let window_id: UInt32
    let app_name: String
    let app_bundle_id: String?
    let window_title: String

    enum CodingKeys: String, CodingKey {
        case window_id = "window-id"
        case app_name = "app-name"
        case app_bundle_id = "app-bundle-id"
        case window_title = "window-title"
    }
}
