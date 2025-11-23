import AppKit
import Common
import Foundation

let stateFileName = isDebug ? ".aerospace-state-debug.json" : ".aerospace-state.json"
var stateFileUrl: URL {
    FileManager.default.homeDirectoryForCurrentUser.appending(path: stateFileName)
}

@MainActor var shouldSaveWorldState = true

@MainActor
func saveWorldState() {
    guard shouldSaveWorldState else { return }
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
    if isDebug { printStderr("[restore] reading state from \(stateFileUrl.path)") }
    guard let data = try? Data(contentsOf: stateFileUrl) else {
        if isDebug { printStderr("[restore] can't read state file") }
        return false
    }
    if isDebug { printStderr("[restore] state file size: \(data.count) bytes") }
    guard let world = try? JSONDecoder().decode(FrozenWorld.self, from: data) else {
        if isDebug { printStderr("[restore] failed to decode state file") }
        return false
    }
    setClosedWindowsCache(world)
    if isDebug { printStderr("[restore] decoded \(world.workspaces.count) workspaces, \(world.monitors.count) monitors") }
    let currentMonitors = monitors
    let topLeftCornerToMonitor = currentMonitors.grouped { $0.rect.topLeftCorner }
    for frozenWorkspace in world.workspaces {
        if isDebug {
            printStderr(
                "[restore] workspace '\(frozenWorkspace.name)' orientation=" +
                    "\(frozenWorkspace.rootTilingNode.orientation) layout=" +
                    "\(frozenWorkspace.rootTilingNode.layout)" )
        }
        let workspace = Workspace.get(byName: frozenWorkspace.name)
        let ok = topLeftCornerToMonitor[frozenWorkspace.monitor.topLeftCorner]?.singleOrNil()?.setActiveWorkspace(workspace) ?? false
        if isDebug { printStderr("[restore]  assign monitor \(frozenWorkspace.monitor.topLeftCorner) -> \(ok)") }
        for frozenWindow in frozenWorkspace.floatingWindows {
            if let win = MacWindow.get(byId: frozenWindow.id) {
                win.bindAsFloatingWindow(to: workspace)
                if isDebug { printStderr("[restore]  bound floating window \(frozenWindow.id)") }
            } else if isDebug {
                printStderr("[restore]  missing floating window \(frozenWindow.id)")
            }
        }
        for frozenWindow in frozenWorkspace.macosUnconventionalWindows {
            if let win = MacWindow.get(byId: frozenWindow.id) {
                win.bindAsFloatingWindow(to: workspace)
                if isDebug { printStderr("[restore]  bound macOS window \(frozenWindow.id)") }
            } else if isDebug {
                printStderr("[restore]  missing macOS window \(frozenWindow.id)")
            }
        }
        let prevRoot = workspace.rootTilingContainer
        let potentialOrphans = prevRoot.allLeafWindowsRecursive
        prevRoot.unbindFromParent()
        if isDebug { printStderr("[restore]  rebuilding root container") }
        _ = restoreTreeRecursive(frozenContainer: frozenWorkspace.rootTilingNode, parent: workspace, index: INDEX_BIND_LAST)
        for window in (potentialOrphans - workspace.rootTilingContainer.allLeafWindowsRecursive) {
            try? await window.relayoutWindow(on: workspace, forceTile: true)
        }
    }
    for monitor in world.monitors {
        let ok = topLeftCornerToMonitor[monitor.topLeftCorner]?.singleOrNil()?.setActiveWorkspace(Workspace.get(byName: monitor.visibleWorkspace)) ?? false
        if isDebug { printStderr("[restore] set visible workspace '\(monitor.visibleWorkspace)' for monitor \(monitor.topLeftCorner) -> \(ok)") }
    }
    if isDebug { printStderr("[restore] done") }
    return true
}
