import AppKit
import Common
import Foundation

let stateFileName = isDebug ? ".aerospace-state-debug.json" : ".aerospace-state.json"
var stateFileUrl: URL {
    FileManager.default.homeDirectoryForCurrentUser.appending(path: stateFileName)
}

@MainActor
func saveWorldState() {
    let allWs = Workspace.all
    let world = FrozenWorld(
        workspaces: allWs.map { FrozenWorkspace($0) },
        monitors: monitors.map(FrozenMonitor.init),
        windowIds: allWs.flatMap { collectAllWindowIds(workspace: $0) }.toSet()
    )
    guard let str = JSONEncoder.aeroSpaceDefault.encodeToString(world) else { return }
    try? str.write(to: stateFileUrl, atomically: true, encoding: .utf8)
}

@MainActor
func restoreWorldState() async -> Bool {
    guard let data = try? Data(contentsOf: stateFileUrl) else { return false }
    guard let world = try? JSONDecoder().decode(FrozenWorld.self, from: data) else { return false }
    let currentMonitors = monitors
    let topLeftCornerToMonitor = currentMonitors.grouped { $0.rect.topLeftCorner }
    for frozenWorkspace in world.workspaces {
        let workspace = Workspace.get(byName: frozenWorkspace.name)
        _ = topLeftCornerToMonitor[frozenWorkspace.monitor.topLeftCorner]?.singleOrNil()?.setActiveWorkspace(workspace)
        for frozenWindow in frozenWorkspace.floatingWindows {
            MacWindow.get(byId: frozenWindow.id)?.bindAsFloatingWindow(to: workspace)
        }
        for frozenWindow in frozenWorkspace.macosUnconventionalWindows {
            MacWindow.get(byId: frozenWindow.id)?.bindAsFloatingWindow(to: workspace)
        }
        let prevRoot = workspace.rootTilingContainer
        let potentialOrphans = prevRoot.allLeafWindowsRecursive
        prevRoot.unbindFromParent()
        restoreTreeRecursive(frozenContainer: frozenWorkspace.rootTilingNode, parent: workspace, index: INDEX_BIND_LAST)
        for window in (potentialOrphans - workspace.rootTilingContainer.allLeafWindowsRecursive) {
            try? await window.relayoutWindow(on: workspace, forceTile: true)
        }
    }
    for monitor in world.monitors {
        _ = topLeftCornerToMonitor[monitor.topLeftCorner]?.singleOrNil()?.setActiveWorkspace(Workspace.get(byName: monitor.visibleWorkspace))
    }
    return true
}
