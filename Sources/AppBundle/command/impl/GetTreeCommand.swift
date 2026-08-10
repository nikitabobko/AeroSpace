import AppKit
import Common

struct GetTreeCommand: Command {
    let args: GetTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        var monitors: [Json] = []
        for monitor in sortedMonitors {
            var workspaceNodes: [Json] = []
            for workspace in Workspace.all where workspace.workspaceMonitor.rect.topLeftCorner == monitor.rect.topLeftCorner {
                workspaceNodes.append(await workspaceToJson(workspace))
            }
            monitors.append(.dict([
                "type": .string("monitor"),
                "id": .int(monitor.monitorAppKitNsScreenScreensId),
                "name": .string(monitor.name),
                "workspaces": .array(workspaceNodes),
            ]))
        }
        let root = Json.dict([
            "type": .string("root"),
            "monitors": .array(monitors),
        ])
        guard let str = JSONEncoder.aeroSpaceDefault.encodeToString(root) else { return .fail(io.err(bugPrompt())) }
        return .succ(io.out(str))
    }
}

private func groupLabel(_ node: TreeNode) -> String? {
    switch node.nodeCases {
        case .floatingWindowsContainer: "floating"
        case .macosFullscreenWindowsContainer: "macos-fullscreen"
        case .macosHiddenAppsWindowsContainer: "macos-hidden-apps"
        case .macosMinimizedWindowsContainer: "macos-minimized"
        case .macosPopupWindowsContainer: "macos-popup"
        case .window, .tilingContainer: nil
        case .workspace: die("Workspace can't be a child")
    }
}

extension TilingContainer {
    fileprivate var layoutString: String {
        switch layout {
            case .tiles: "tiles"
            case .accordion: "accordion"
        }
    }

    fileprivate var orientationString: String { orientation == .h ? "horizontal" : "vertical" }
}

@MainActor
private func workspaceToJson(_ workspace: Workspace) async -> Json {
    let root = workspace.rootTilingContainer
    var nodes: [Json] = await tilingChildrenToJson(root)
    for child in workspace.children where !(child is TilingContainer) && !(child is FloatingWindowsContainer) {
        if let group = await groupToJson(child) {
            nodes.append(group)
        }
    }
    var floatingNodes: [Json] = []
    for window in workspace.floatingWindows {
        floatingNodes.append(await windowToJson(window))
    }
    return .dict([
        "type": .string("workspace"),
        "name": .string(workspace.name),
        "layout": .string(root.layoutString),
        "orientation": .string(root.orientationString),
        "focused": .bool(focus.workspace == workspace && focus.windowOrNil == nil),
        "visible": .bool(workspace.isVisible),
        "nodes": .array(nodes),
        "floating-windows": .array(floatingNodes),
    ])
}

@MainActor
private func tilingChildrenToJson(_ container: TilingContainer) async -> [Json] {
    var result: [Json] = []
    for child in container.children {
        switch child.tilingTreeNodeCasesOrDie() {
            case .window(let window):
                result.append(await windowToJson(window))
            case .tilingContainer(let child):
                result.append(await containerToJson(child))
        }
    }
    return result
}

@MainActor
private func containerToJson(_ container: TilingContainer) async -> Json {
    .dict([
        "type": .string("container"),
        "layout": .string(container.layoutString),
        "orientation": .string(container.orientationString),
        "nodes": .array(await tilingChildrenToJson(container)),
    ])
}

@MainActor
private func groupToJson(_ node: TreeNode) async -> Json? {
    if node.children.isEmpty { return nil } // Don't print empty groups
    var nodes: [Json] = []
    for child in node.children {
        guard let window = child as? Window else { continue }
        nodes.append(await windowToJson(window))
    }
    return .dict([
        "type": .string("group"),
        "name": .string(groupLabel(node).orDie()),
        "nodes": .array(nodes),
    ])
}

@MainActor
private func windowToJson(_ window: Window) async -> Json {
    let title = (try? await window.getTitle(.nonCancellable)) ?? ""
    let isNativeFullscreen = window.parent is MacosFullscreenWindowsContainer
    return .dict([
        "type": .string("window"),
        "window-id": .int(window.windowId),
        "window-title": .string(title),
        "app-bundle-id": .stringOrNull(window.app.rawAppBundleId),
        "app-pid": .int(Int(window.app.pid)),
        "focused": .bool(window == focus.windowOrNil),
        "fullscreen": .bool(window.isFullscreen || isNativeFullscreen),
    ])
}
