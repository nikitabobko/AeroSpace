import AppKit
import Common

/// First line of defence against lock screen
///
/// When you lock the screen, all accessibility API becomes unobservable (all attributes become empty, window id
/// becomes nil, etc.) which tricks AeroSpace into thinking that all windows were closed.
/// That's why every time a window dies AeroSpace caches the "entire world" (unless window is already presented in the cache)
/// so that once the screen is unlocked, AeroSpace could restore windows to where they were
@MainActor private var closedWindowsCache = FrozenWorld(monitors: [], windowIds: [])

struct FrozenMonitor: Sendable {
    let visibleWorkspace: String
    let topLeftCorner: CGPoint
    let workspaces: [FrozenWorkspace]

    @MainActor init(_ monitor: Monitor) {
        self.topLeftCorner = monitor.info.rect.topLeftCorner
        self.workspaces = monitor.getWorkspacesContainerOrCreate().children.map { FrozenWorkspace($0 as! Workspace) }
        self.visibleWorkspace = monitor.getWorkspacesContainerOrCreate().getVisibleWorkspaceOrCreate(parent: monitor).name
    }
}

struct FrozenWorkspace: Sendable {
    let name: String
    let rootTilingNode: FrozenContainer
    let floatingWindows: [FrozenWindow]
    let macosUnconventionalWindows: [FrozenWindow]
    /// Window ids in the order to replay markAsMostRecentChild (least recent first), see mruReplayOrder.
    /// Restoring the tree binds the windows in tree order, and every bind marks the window as the most recent one.
    /// Without the replay the last window of every container becomes its MRU child, and focusing the workspace
    /// later focuses that window instead of the one that was focused last
    let mruReplay: [OpaqueWindowId]

    @MainActor init(_ workspace: Workspace) {
        name = workspace.name
        rootTilingNode = FrozenContainer(workspace.rootTilingContainer)
        floatingWindows = workspace.floatingWindows.map(FrozenWindow.init)
        macosUnconventionalWindows =
            workspace.macOsNativeHiddenAppsWindowsContainer.children.map { FrozenWindow($0 as! Window) } +
            workspace.macOsNativeFullscreenWindowsContainer.children.map { FrozenWindow($0 as! Window) }
        mruReplay = mruReplayOrder(workspace)
    }
}

@MainActor func cacheClosedWindowIfNeeded() {
    let allWs = Workspace.all
    let allWindowIds = allWs.flatMap { collectAllWindowIdsRecursive($0) }.toSet()
    if allWindowIds.isSubset(of: closedWindowsCache.windowIds) {
        return // already cached
    }
    closedWindowsCache = FrozenWorld(
        monitors: Monitor.all.map(FrozenMonitor.init),
        windowIds: allWindowIds,
    )
}

@MainActor func restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: Window) async throws -> Bool {
    if !closedWindowsCache.windowIds.contains(newlyDetectedWindow.windowId) {
        return false
    }
    let monitors = globalUnsortedMonitorInfos
    let topLeftCornerToMonitorInfo = monitors.grouped { $0.rect.topLeftCorner }

    for monitor in closedWindowsCache.monitors {
        for frozenWorkspace in monitor.workspaces {
            let workspace = Workspace.get(byName: frozenWorkspace.name)
            _ = topLeftCornerToMonitorInfo[monitor.topLeftCorner]?
                .singleOrNil()?
                .bindWorkspace(workspace)
            for frozenWindow in frozenWorkspace.floatingWindows {
                MacWindow.get(byId: frozenWindow.id)?.bindAsFloatingWindow(to: workspace)
            }
            for frozenWindow in frozenWorkspace.macosUnconventionalWindows { // Will get fixed by normalizations
                MacWindow.get(byId: frozenWindow.id)?.bindAsFloatingWindow(to: workspace)
            }
            let prevRoot = workspace.rootTilingContainer // Save prevRoot into a variable to avoid it being garbage collected earlier than needed
            let potentialOrphans = prevRoot.allLeafWindowsRecursive
            prevRoot.unbindFromParent()
            restoreTreeRecursive(frozenContainer: frozenWorkspace.rootTilingNode, parent: workspace, index: INDEX_BIND_LAST)
            for window in (potentialOrphans - workspace.rootTilingContainer.allLeafWindowsRecursive) {
                try await window.relayoutWindow(on: workspace, .cancellable, forceTile: true)
            }
            for id in frozenWorkspace.mruReplay {
                // Skip windows that weren't restored to this workspace, to keep the MRU of their current workspace
                if let window = Window.get(byId: id), window.nodeWorkspace == workspace {
                    window.markAsMostRecentChild()
                }
            }
        }

        _ = topLeftCornerToMonitorInfo[monitor.topLeftCorner]?
            .singleOrNil()?
            .setVisibleWorkspace(Workspace.get(byName: monitor.visibleWorkspace))
    }
    // The focus may have changed after the world was frozen. Keep the focused window the most recent one
    globalFocus.windowOrNil?.markAsMostRecentChild()
    return true
}

@discardableResult
@MainActor
private func restoreTreeRecursive(frozenContainer: FrozenContainer, parent: NonLeafTreeNodeObject, index: Int) -> Bool {
    let container = TilingContainer(
        parent: parent,
        adaptiveWeight: frozenContainer.weight,
        frozenContainer.orientation,
        frozenContainer.layout,
        index: index,
    )

    for (index, child) in frozenContainer.children.enumerated() {
        switch child {
            case .window(let w):
                // Stop the loop if can't find the window, because otherwise all the subsequent windows will have incorrect index
                guard let window = MacWindow.get(byId: w.id) else { return false }
                window.bind(to: container, adaptiveWeight: w.weight, index: index)
            case .container(let c):
                // There is no reason to continue
                if !restoreTreeRecursive(frozenContainer: c, parent: container, index: index) { return false }
        }
    }
    return true
}

// Consider the following case:
// 1. Close window
// 2. The previous step lead to caching the whole world
// 3. Change something in the layout
// 4. Lock the screen
// 5. The cache won't be updated because all alive windows are already cached
// 6. Unlock the screen
// 7. The wrong cache is used
//
// That's why we have to reset the cache every time layout changes. The layout can only be changed by running commands
// and with mouse manipulations
@MainActor func resetClosedWindowsCache() {
    closedWindowsCache = FrozenWorld(monitors: [], windowIds: [])
}
