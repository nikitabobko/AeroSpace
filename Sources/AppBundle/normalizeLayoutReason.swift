import AppKit
import Common

private let nativeFullscreenRestorePointKey = TreeNodeUserDataKey<NativeFullscreenRestorePoint>(key: "nativeFullscreenRestorePoint")
private let nativeFullscreenRestoreRetryKey = TreeNodeUserDataKey<Task<Void, Never>>(key: "nativeFullscreenRestoreRetry")

// Keep fullscreen windows detached. Only restore a saved branch if the current tree can
// be explained by removing the window, normalizing containers, and applying layout.
// Unaffected subtrees are opaque anchors: edits inside them must survive restoration.
private struct NativeFullscreenRestorePoint {
    let binding: BindingData
    let root: FullscreenRestoreTree
    let flatten: Bool
    let oppositeOrientation: Bool
    var firstExitAttempt: ContinuousClock.Instant?

    @MainActor init(binding: BindingData, workspace: Workspace) {
        self.binding = binding
        root = FullscreenRestoreTree(workspace.rootTilingContainer, affectedParent: binding.parent)
        flatten = config.enableNormalizationFlattenContainers
        oppositeOrientation = config.enableNormalizationOppositeOrientationForNestedContainers
    }

    @MainActor mutating func shouldWaitForSpaceTransition(window: Window, workspace: Workspace) -> Bool {
        guard window.parent === workspace.macOsNativeFullscreenWindowsContainer,
              root.node === workspace.rootTilingContainer,
              root.hasTemporarilyInvisibleWindows
        else { return false }
        let started = firstExitAttempt ?? .now
        firstExitAttempt = started
        guard started.duration(to: .now) < .seconds(3) else { return false }
        if !isUnitTest, window.getUserData(key: nativeFullscreenRestoreRetryKey) == nil {
            let retry = Task.startUnstructured { @MainActor [weak window] in
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let window else { return }
                window.cleanUserData(key: nativeFullscreenRestoreRetryKey)
                guard window.getUserData(key: nativeFullscreenRestorePointKey) != nil else { return }
                scheduleCancellableCompleteRefreshSession(.globalObserver("nativeFullscreenRestore"))
            }
            window.putUserData(key: nativeFullscreenRestoreRetryKey, data: retry)
        }
        return true
    }

    @MainActor func restore(window: Window, workspace: Workspace) -> Bool {
        guard window.parent === workspace.macOsNativeFullscreenWindowsContainer,
              root.node === workspace.rootTilingContainer,
              flatten == config.enableNormalizationFlattenContainers,
              oppositeOrientation == config.enableNormalizationOppositeOrientationForNestedContainers
        else { return false }

        var expected = root
        // Each normalization can remove containers or change their orientation. Accept
        // intermediate states too: fullscreen may end before the next refresh session.
        for _ in 0 ... root.containerCount {
            if expected.matches() {
                root.restore(to: workspace, index: INDEX_BIND_LAST, window: window, binding: binding)
                window.markAsMostRecentChild()
                return true
            }
            expected = expected.normalized(isRoot: true, flatten: flatten).orDie()
            if oppositeOrientation { expected.normalizeOrientations(parent: nil, flatten: flatten) }
        }
        return false
    }
}

private struct FullscreenRestoreTree {
    let node: TreeNode
    var weight: CGFloat
    var orientation: Orientation?
    var layout: Layout?
    var children: [FullscreenRestoreTree]
    let affected: Bool
    let wasInhabited: Bool

    @MainActor init(_ node: TreeNode, affectedParent: NonLeafTreeNodeObject) {
        self.node = node
        weight = (node.parent as? TilingContainer).map { node.getWeight($0.orientation) } ?? 1
        orientation = (node as? TilingContainer)?.orientation
        layout = (node as? TilingContainer)?.layout
        children = node.children.map { FullscreenRestoreTree($0, affectedParent: affectedParent) }
        affected = node === affectedParent || children.contains { $0.affected }
        wasInhabited = node.tilingTreeNodeCasesOrDie().isInhabited
    }

    var containerCount: Int { (orientation == nil ? 0 : 1) + children.reduce(0) { $0 + $1.containerCount } }

    @MainActor var hasTemporarilyInvisibleWindows: Bool {
        if let window = node as? Window {
            return wasInhabited && window.isBound && window.lifeStatus == .invisible
        }
        return children.contains { $0.hasTemporarilyInvisibleWindows }
    }

    @MainActor func matches() -> Bool {
        if let window = node as? Window { return window.lifeStatus != .dead }
        guard let container = node as? TilingContainer else { return false }
        if !affected { return true }
        guard container.orientation == orientation, container.layout == layout,
              container.children.count == children.count,
              zip(container.children, children).allSatisfy({ $0 === $1.node })
        else { return false }

        var weightDeltas: [Bool: CGFloat] = [:]
        for (actual, saved) in zip(container.children, children) {
            guard actual === saved.node, saved.matches() else { return false }
            // layoutTiles adjusts inhabited children while invisible children keep
            // their weights. Compare each group separately during Space transitions.
            if layout == .tiles {
                let inhabited = actual.tilingTreeNodeCasesOrDie().isInhabited
                let delta = actual.getWeight(container.orientation) - saved.weight
                let expectedDelta = weightDeltas[inhabited] ?? delta
                if abs(delta - expectedDelta) > 0.001 { return false }
                weightDeltas[inhabited] = expectedDelta
            }
        }
        return true
    }

    func normalized(isRoot: Bool, flatten: Bool) -> FullscreenRestoreTree? {
        guard orientation != nil else { return self }
        var result = self
        if flatten, let child = children.singleOrNil() {
            if isRoot {
                if child.orientation != nil {
                    // Current normalization copies a single child container into the
                    // existing root; the root's identity stays the same.
                    result.orientation = child.orientation
                    result.layout = child.layout
                    result.children = child.children
                }
            } else {
                var replacement = child
                replacement.weight = weight
                return replacement.normalized(isRoot: false, flatten: flatten)
            }
        }
        result.children = result.children.compactMap { $0.normalized(isRoot: false, flatten: flatten) }
        return !isRoot && result.children.isEmpty ? nil : result
    }

    mutating func normalizeOrientations(parent: Orientation?, flatten: Bool) {
        guard orientation != nil else { return }
        if let parent { orientation = flatten && children.count == 1 ? parent : parent.opposite }
        for i in children.indices { children[i].normalizeOrientations(parent: orientation, flatten: flatten) }
    }

    @MainActor func restore(to parent: NonLeafTreeNodeObject, index: Int, window: Window, binding: BindingData) {
        guard let container = node as? TilingContainer else {
            node.bind(to: parent, adaptiveWeight: weight, index: index)
            return
        }
        if !affected && container.isBound {
            container.bind(to: parent, adaptiveWeight: weight, index: index)
            return
        }

        let restored: TilingContainer
        if container.orientation == orientation {
            container.lifeStatus = .alive
            container.layout = layout.orDie()
            container.bind(to: parent, adaptiveWeight: weight, index: index)
            restored = container
        } else {
            if container.isBound { container.unbindFromParent() }
            restored = TilingContainer(parent: parent, adaptiveWeight: weight, orientation.orDie(), layout.orDie(), index: index)
        }
        for (i, child) in children.enumerated() {
            child.restore(to: restored, index: i, window: window, binding: binding)
        }
        if node === binding.parent {
            window.bind(to: restored, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
        }
    }
}

@MainActor func enterMacOsNativeFullscreen(window: Window, workspace: Workspace) {
    guard let parent = window.windowParentCases, parent.kind != .macosFullscreenWindowsContainer else { return }
    window.layoutReason = .macos(prevParentKind: parent.kind)
    let binding = window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST).orDie()
    if case .tilingContainer = parent {
        let point = NativeFullscreenRestorePoint(binding: binding, workspace: workspace)
        window.putUserData(key: nativeFullscreenRestorePointKey, data: point)
    }
}

@MainActor func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: globalFocus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        let popup = (node as! MacWindow)
        let windowLevel = try await popup.getWindowLevel(.cancellable)
        if try await popup.isWindowHeuristic(windowLevel, .cancellable) {
            try await popup.relayoutWindow(on: globalFocus.workspace, .cancellable)
            await runOnWindowDetected(ifConventional: popup)
        }
    }
}

@MainActor private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    let states = try await windows.mapConcurrently { try await $0.getMacosWindowNativeState(.cancellable) }
    for (window, state) in zip(windows, states) {
        let isMacosFullscreen = state == .nativeFullscreen
        let isMacosMinimized = state == .nativeMinimized
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        switch window.layoutReason {
            case .standard:
                guard let parent = window.windowParentCases else { continue }
                switch true {
                    case isMacosFullscreen:
                        enterMacOsNativeFullscreen(window: window, workspace: workspace)
                    case isMacosMinimized:
                        window.layoutReason = .macos(prevParentKind: parent.kind)
                        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                    case isMacosWindowOfHiddenApp:
                        window.layoutReason = .macos(prevParentKind: parent.kind)
                        window.bind(to: workspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                    default: break
                }
            case .macos(let prevParentKind):
                if !isMacosFullscreen && !isMacosMinimized && !isMacosWindowOfHiddenApp {
                    try await exitMacOsNativeUnconventionalState(window: window, prevParentKind: prevParentKind, workspace: workspace, .cancellable)
                }
        }
    }
}

@MainActor func exitMacOsNativeUnconventionalState(
    window: Window,
    prevParentKind: WindowParentCases.Kind,
    workspace: Workspace,
    _ cm: CancellationMode,
) async throws {
    if var point = window.getUserData(key: nativeFullscreenRestorePointKey),
       point.shouldWaitForSpaceTransition(window: window, workspace: workspace)
    {
        window.putUserData(key: nativeFullscreenRestorePointKey, data: point)
        return
    }
    window.cleanUserData(key: nativeFullscreenRestoreRetryKey)?.cancel()
    window.layoutReason = .standard
    if window.cleanUserData(key: nativeFullscreenRestorePointKey)?.restore(window: window, workspace: workspace) == true {
        return
    }
    switch prevParentKind {
        case .floatingWindowsContainer:
            window.bindAsFloatingWindow(to: workspace)
        case .tilingContainer:
            try await window.relayoutWindow(on: workspace, cm, forceTile: true)
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            try await window.relayoutWindow(on: workspace, cm)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            try await window.relayoutWindow(on: workspace, cm)
    }
}
