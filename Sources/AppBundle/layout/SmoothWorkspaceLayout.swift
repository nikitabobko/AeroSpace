import AppKit
import Common

private indirect enum SmoothTreeShape: Equatable {
    case window
    case container(isHorizontal: Bool, isTiles: Bool, children: [SmoothTreeShape])
}

private struct SmoothWorkspaceLayoutSnapshot {
    let monitorIdentifier: String
    let monitorIsHorizontal: Bool
    let style: SmoothLayoutStyle
    let customLayout: SmoothCustomLayoutBlueprint?
    var windowIds: [UInt32]
    let treeShape: SmoothTreeShape
    let usesConstraintFallback: Bool

    func canReuseLayout(
        monitorIdentifier: String,
        monitorIsHorizontal: Bool,
        style: SmoothLayoutStyle,
        customLayout: SmoothCustomLayoutBlueprint?,
        windowIds: [UInt32],
        treeShape: SmoothTreeShape,
    ) -> Bool {
        self.monitorIdentifier == monitorIdentifier &&
            self.monitorIsHorizontal == monitorIsHorizontal &&
            self.style == style &&
            self.customLayout == customLayout &&
            self.windowIds.toSet() == windowIds.toSet() &&
            self.treeShape == treeShape
    }
}

@MainActor
func replaceSmoothLayoutWindowId(_ oldId: UInt32, with newId: UInt32) {
    for name in smoothWorkspaceLayoutSnapshots.keys {
        let ids = smoothWorkspaceLayoutSnapshots[name]!.windowIds.map {
            $0 == oldId ? newId : $0
        }
        smoothWorkspaceLayoutSnapshots[name]?.windowIds = ids
    }
}

@MainActor
private var smoothWorkspaceLayoutSnapshots: [String: SmoothWorkspaceLayoutSnapshot] = [:]

// Tree commands are normalized after they run. Remember the user's intent until
// that normalization pass finishes, then adopt the normalized result as the new
// stable Smooth topology instead of rebuilding the configured preset over it.
@MainActor
private var smoothWorkspaceManualTreeOverrides: Set<String> = []

@MainActor
private var isReconcilingSmoothWorkspaceLayouts = false

@MainActor
func invalidateSmoothWorkspaceLayoutSnapshots() {
    smoothWorkspaceLayoutSnapshots = [:]
    smoothWorkspaceManualTreeOverrides = []
}

@MainActor
func invalidateSmoothWorkspaceLayoutSnapshot(workspaceName: String) {
    smoothWorkspaceLayoutSnapshots.removeValue(forKey: workspaceName)
    smoothWorkspaceManualTreeOverrides.remove(workspaceName)
}

@MainActor
func preserveCurrentSmoothWorkspaceTreeAfterUserCommand(_ workspace: Workspace) {
    guard let previous = smoothWorkspaceLayoutSnapshots[workspace.name] else { return }
    let currentWindows = workspace.rootTilingContainer.allLeafWindowsRecursive
    guard previous.windowIds.toSet() == currentWindows.map(\.windowId).toSet() else {
        smoothWorkspaceLayoutSnapshots.removeValue(forKey: workspace.name)
        smoothWorkspaceManualTreeOverrides.remove(workspace.name)
        return
    }
    smoothWorkspaceManualTreeOverrides.insert(workspace.name)
    smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
        monitorIdentifier: previous.monitorIdentifier,
        monitorIsHorizontal: previous.monitorIsHorizontal,
        style: previous.style,
        customLayout: previous.customLayout,
        windowIds: currentWindows.map(\.windowId),
        treeShape: smoothTreeShape(workspace.rootTilingContainer),
        usesConstraintFallback: previous.usesConstraintFallback,
    )
}

@MainActor
func reconcileSmoothWorkspaceLayouts() {
    reconcileSmoothWorkspaceLayouts(constraintFallbackWorkspaces: [])
}

@MainActor
func reconcileSmoothWorkspaceLayoutsRespectingWindowConstraints() async {
    // The selected layout is authoritative. Falling back to Grid when an app
    // reports a larger minimum AX size makes an explicit Dwindle selection
    // appear to be ignored and causes the tree to change again moments later.
    // macOS may clamp that individual window, but keep the requested topology.
    reconcileSmoothWorkspaceLayouts()
}

@MainActor
private func reconcileSmoothWorkspaceLayouts(constraintFallbackWorkspaces: Set<String>) {
    guard !isReconcilingSmoothWorkspaceLayouts else { return }
    isReconcilingSmoothWorkspaceLayouts = true
    defer { isReconcilingSmoothWorkspaceLayouts = false }

    enforceSmoothMonitorTileLimits()

    let existingWorkspaceNames = Workspace.all.filter(\.isUserFacing).map(\.name).toSet()
    smoothWorkspaceLayoutSnapshots = smoothWorkspaceLayoutSnapshots.filter { existingWorkspaceNames.contains($0.key) }

    for workspace in Workspace.all where workspace.isUserFacing {
        let root = workspace.rootTilingContainer
        let currentWindows = root.allLeafWindowsRecursive
        guard !currentWindows.isEmpty else {
            smoothWorkspaceLayoutSnapshots.removeValue(forKey: workspace.name)
            continue
        }

        let monitor = workspace.workspaceMonitor
        let profile = SmoothLayoutSettingsStore.shared.profile(for: monitor)
        guard profile.enabled else {
            smoothWorkspaceLayoutSnapshots.removeValue(forKey: workspace.name)
            continue
        }

        let style = profile.style(for: currentWindows.count)
        let customLayout = style == .manual ? profile.customLayout(for: currentWindows.count) : nil
        let previous = smoothWorkspaceLayoutSnapshots[workspace.name]
        let currentWindowIds = currentWindows.map(\.windowId)
        let monitorIsHorizontal = monitor.width >= monitor.height
        let currentTreeShape = smoothTreeShape(root)

        if smoothWorkspaceManualTreeOverrides.remove(workspace.name) != nil,
           let previous,
           previous.windowIds.toSet() == currentWindowIds.toSet()
        {
            smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
                monitorIdentifier: monitor.stableIdentifier,
                monitorIsHorizontal: monitorIsHorizontal,
                style: style,
                customLayout: customLayout,
                windowIds: currentWindowIds,
                treeShape: currentTreeShape,
                usesConstraintFallback: false,
            )
            continue
        }

        // Profiles created before the visual Custom editor have no blueprint.
        // Preserve their original manual/no-op behavior until a design is saved.
        if style == .manual, customLayout == nil {
            if let previous, previous.style != .manual, previous.windowIds.count == 1 {
                for window in currentWindows { window.isFullscreen = false }
            }
            smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
                monitorIdentifier: monitor.stableIdentifier,
                monitorIsHorizontal: monitorIsHorizontal,
                style: style,
                customLayout: nil,
                windowIds: currentWindowIds,
                treeShape: currentTreeShape,
                usesConstraintFallback: false,
            )
            continue
        }

        if constraintFallbackWorkspaces.contains(workspace.name) {
            let orderedWindows = orderWindows(currentWindows, preserving: previous)
            workspace.applySmoothLayout(.grid, to: orderedWindows, monitor: monitor)
            smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
                monitorIdentifier: monitor.stableIdentifier,
                monitorIsHorizontal: monitorIsHorizontal,
                style: style,
                customLayout: customLayout,
                windowIds: orderedWindows.map(\.windowId),
                treeShape: smoothTreeShape(root),
                usesConstraintFallback: true,
            )
            continue
        }

        // A swap, focus change, or manual resize must not trigger a complete
        // rebuild. Besides feeling abrupt, rebuilding in response to AX events
        // generated by that same rebuild can create a feedback loop. Track the
        // new DFS order and only rebuild when membership or profile changes.
        if previous?.canReuseLayout(
            monitorIdentifier: monitor.stableIdentifier,
            monitorIsHorizontal: monitorIsHorizontal,
            style: style,
            customLayout: customLayout,
            windowIds: currentWindowIds,
            treeShape: currentTreeShape,
        ) == true {
            smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
                monitorIdentifier: monitor.stableIdentifier,
                monitorIsHorizontal: monitorIsHorizontal,
                style: style,
                customLayout: customLayout,
                windowIds: currentWindowIds,
                treeShape: currentTreeShape,
                usesConstraintFallback: previous?.usesConstraintFallback ?? false,
            )
            continue
        }

        let orderedWindows = orderWindows(currentWindows, preserving: previous)
        if let customLayout {
            workspace.applySmoothCustomLayout(customLayout, to: orderedWindows, monitor: monitor)
        } else {
            workspace.applySmoothLayout(style, to: orderedWindows, monitor: monitor)
        }
        smoothWorkspaceLayoutSnapshots[workspace.name] = SmoothWorkspaceLayoutSnapshot(
            monitorIdentifier: monitor.stableIdentifier,
            monitorIsHorizontal: monitorIsHorizontal,
            style: style,
            customLayout: customLayout,
            windowIds: orderedWindows.map(\.windowId),
            treeShape: smoothTreeShape(root),
            usesConstraintFallback: false,
        )
    }
}

func smoothWindowExceedsTile(actual: Rect, target: Rect, tolerance: CGFloat = 8) -> Bool {
    actual.width > target.width + tolerance || actual.height > target.height + tolerance
}

private func smoothTreeShape(_ node: TreeNode) -> SmoothTreeShape {
    switch node.nodeCases {
        case .window:
            .window
        case .tilingContainer(let container):
            .container(
                isHorizontal: container.orientation == .h,
                isTiles: container.layout == .tiles,
                children: container.children.map(smoothTreeShape),
            )
        case .workspace, .macosMinimizedWindowsContainer,
             .macosHiddenAppsWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .floatingWindowsContainer:
            dieT("Smooth layout shape only supports tiling trees")
    }
}

@MainActor
private func enforceSmoothMonitorTileLimits() {
    let persistentOrder = Dictionary(
        uniqueKeysWithValues: config.persistentWorkspaces.enumerated().map { ($0.element, $0.offset) },
    )
    let groupedWorkspaces = Dictionary(grouping: Workspace.all.filter(\.isUserFacing)) { $0.workspaceMonitor.name }

    for (_, unsortedWorkspaces) in groupedWorkspaces {
        let workspaces = unsortedWorkspaces.sorted {
            (persistentOrder[$0.name] ?? Int.max, $0.name) <
                (persistentOrder[$1.name] ?? Int.max, $1.name)
        }
        guard let monitor = workspaces.first?.workspaceMonitor else { continue }
        let profile = SmoothLayoutSettingsStore.shared.profile(for: monitor)
        guard profile.enabled else { continue }

        let limit = profile.tileLimit
        var counts = Dictionary(
            uniqueKeysWithValues: workspaces.map { ($0.name, $0.rootTilingContainer.allLeafWindowsRecursive.count) },
        )

        for source in workspaces {
            let sourceWindows = source.rootTilingContainer.allLeafWindowsRecursive
            guard sourceWindows.count > limit else { continue }

            for window in sourceWindows.dropFirst(limit) {
                guard let target = workspaces.first(where: {
                    $0 !== source && (counts[$0.name] ?? 0) < limit
                }) else { break }

                window.bind(
                    to: target.rootTilingContainer,
                    adaptiveWeight: WEIGHT_AUTO,
                    index: INDEX_BIND_LAST,
                )
                counts[source.name, default: sourceWindows.count] -= 1
                counts[target.name, default: 0] += 1
            }
        }
    }
}

private func orderWindows(
    _ currentWindows: [Window],
    preserving previous: SmoothWorkspaceLayoutSnapshot?,
) -> [Window] {
    guard let previous else { return currentWindows }

    let windowsById = Dictionary(uniqueKeysWithValues: currentWindows.map { ($0.windowId, $0) })
    let existingWindows = previous.windowIds.compactMap { windowsById[$0] }
    let previousIds = previous.windowIds.toSet()
    let newlyAddedWindows = currentWindows.filter { !previousIds.contains($0.windowId) }
    return existingWindows + newlyAddedWindows
}

extension Workspace {
    @MainActor
    fileprivate func applySmoothCustomLayout(
        _ blueprint: SmoothCustomLayoutBlueprint,
        to windows: [Window],
        monitor: MonitorInfo,
    ) {
        guard blueprint.windowCount == windows.count, blueprint.isValid, !windows.isEmpty else { return }

        let root = rootTilingContainer
        let previouslyFocusedWindow = focus.windowOrNil?.takeIf { windows.contains($0) }
        for window in windows where window.isBound {
            window.unbindFromParent()
        }
        for child in root.children {
            child.unbindFromParent()
        }
        for window in windows { window.isFullscreen = false }

        switch blueprint.root {
            case .window(let slot):
                configureRoot(root, orientation: monitor.width >= monitor.height ? .h : .v)
                bindSmoothWindow(windows[slot], to: root, weight: 1)
                windows[slot].isFullscreen = true
            case .split(let axis, let ratio, let first, let second):
                configureRoot(root, orientation: axis.orientation)
                bindCustomNode(first, to: root, weight: ratio, windows: windows)
                bindCustomNode(second, to: root, weight: 1 - ratio, windows: windows)
        }

        previouslyFocusedWindow?.markAsMostRecentChild()
    }

    @MainActor
    fileprivate func applySmoothLayout(_ requestedStyle: SmoothLayoutStyle, to windows: [Window], monitor: MonitorInfo) {
        guard !windows.isEmpty, requestedStyle != .manual else { return }

        let root = rootTilingContainer
        let previouslyFocusedWindow = focus.windowOrNil?.takeIf { windows.contains($0) }

        // Detach leaves first, then discard the now-empty container hierarchy.
        // The workspace root itself stays alive so commands holding a reference to
        // it remain valid during this single coordinated layout transaction.
        for window in windows where window.isBound {
            window.unbindFromParent()
        }
        for child in root.children {
            child.unbindFromParent()
        }

        for window in windows { window.isFullscreen = false }

        let style: SmoothLayoutStyle = windows.count == 1
            ? .fullscreen
            : requestedStyle == .fullscreen ? .columns : requestedStyle

        switch style {
            case .manual:
                return // Guarded above; keeps the switch exhaustive.
            case .fullscreen:
                configureRoot(root, orientation: monitor.width >= monitor.height ? .h : .v)
                bindSmoothWindow(windows[0], to: root)
                windows[0].isFullscreen = true

            case .columns:
                configureRoot(root, orientation: .h)
                windows.forEach { bindSmoothWindow($0, to: root) }

            case .rows:
                configureRoot(root, orientation: .v)
                windows.forEach { bindSmoothWindow($0, to: root) }

            case .dwindle:
                configureRoot(root, orientation: .h)
                buildDwindle(windows, in: root, orientation: .h)

            case .verticalPairs:
                configureRoot(root, orientation: .v)
                buildRows(windows, in: root, columnsPerRow: 2)

            case .grid:
                configureRoot(root, orientation: .v)
                let aspectRatio = max(Double(monitor.width / monitor.height), 0.1)
                let columnCount = min(
                    windows.count,
                    max(1, Int(ceil(sqrt(Double(windows.count) * aspectRatio)))),
                )
                buildRows(windows, in: root, columnsPerRow: columnCount)
        }

        previouslyFocusedWindow?.markAsMostRecentChild()
    }
}

@MainActor
private func configureRoot(_ root: TilingContainer, orientation: Orientation) {
    root.layout = .tiles
    root.changeOrientation(orientation)
}

@MainActor
private func bindSmoothWindow(_ window: Window, to parent: TilingContainer) {
    window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
}

@MainActor
private func bindSmoothWindow(_ window: Window, to parent: TilingContainer, weight: Double) {
    window.bind(to: parent, adaptiveWeight: CGFloat(weight), index: INDEX_BIND_LAST)
}

@MainActor
private func bindCustomNode(
    _ node: SmoothCustomLayoutNode,
    to parent: TilingContainer,
    weight: Double,
    windows: [Window],
) {
    switch node {
        case .window(let slot):
            bindSmoothWindow(windows[slot], to: parent, weight: weight)
        case .split(let axis, let ratio, let first, let second):
            if parent.orientation == axis.orientation {
                // Flatten equal-axis splits while multiplying their weights.
                // This produces the same geometry and matches AeroSpace's normalizer.
                bindCustomNode(first, to: parent, weight: weight * ratio, windows: windows)
                bindCustomNode(second, to: parent, weight: weight * (1 - ratio), windows: windows)
            } else {
                let container = TilingContainer(
                    parent: parent,
                    adaptiveWeight: CGFloat(weight),
                    axis.orientation,
                    .tiles,
                    index: INDEX_BIND_LAST,
                )
                bindCustomNode(first, to: container, weight: ratio, windows: windows)
                bindCustomNode(second, to: container, weight: 1 - ratio, windows: windows)
            }
    }
}

extension SmoothSplitAxis {
    fileprivate var orientation: Orientation { self == .horizontal ? .h : .v }
}

@MainActor
private func buildDwindle(_ windows: ArraySlice<Window>, in parent: TilingContainer, orientation: Orientation) {
    guard let first = windows.first else { return }
    let remaining = windows.dropFirst()

    bindSmoothWindow(first, to: parent)
    guard !remaining.isEmpty else { return }

    if remaining.count == 1 {
        bindSmoothWindow(remaining.first.orDie(), to: parent)
        return
    }

    let tail = TilingContainer(
        parent: parent,
        adaptiveWeight: WEIGHT_AUTO,
        orientation.opposite,
        .tiles,
        index: INDEX_BIND_LAST,
    )
    buildDwindle(remaining, in: tail, orientation: orientation.opposite)
}

@MainActor
private func buildDwindle(_ windows: [Window], in parent: TilingContainer, orientation: Orientation) {
    buildDwindle(windows[...], in: parent, orientation: orientation)
}

@MainActor
private func buildRows(_ windows: [Window], in root: TilingContainer, columnsPerRow: Int) {
    var index = 0
    while index < windows.count {
        let end = min(index + columnsPerRow, windows.count)
        let rowWindows = windows[index ..< end]

        if rowWindows.count == 1 {
            bindSmoothWindow(rowWindows.first.orDie(), to: root)
        } else {
            let row = TilingContainer(
                parent: root,
                adaptiveWeight: WEIGHT_AUTO,
                .h,
                .tiles,
                index: INDEX_BIND_LAST,
            )
            rowWindows.forEach { bindSmoothWindow($0, to: row) }
        }
        index = end
    }
}
