import AppKit
import Common

private let macosNativeFullscreenRestorePointKey = TreeNodeUserDataKey<MacosNativeFullscreenRestorePoint>(
    key: "macosNativeFullscreenRestorePoint",
)

private struct FlattenedParentRestorePoint {
    let outerBinding: BindingData
    let outerChildren: [TreeNode]
    let layout: Layout?
    let orientation: Orientation?
    let outerChildWeights: [CGFloat]?

    @MainActor
    init?(parent: NonLeafTreeNodeObject) {
        guard let parent = parent as? TilingContainer,
              let outerParent = parent.parent,
              outerParent is TilingContainer || outerParent is Workspace,
              let index = outerParent.children.firstIndex(where: { $0 === parent })
        else { return nil }
        let outerTilingParent = outerParent as? TilingContainer
        self.outerBinding = BindingData(
            parent: outerParent,
            adaptiveWeight: outerTilingParent.map { parent.getWeight($0.orientation) } ?? 1,
            index: index,
        )
        self.outerChildren = outerParent.children
        self.layout = outerTilingParent?.layout
        self.orientation = outerTilingParent?.orientation
        if let outerTilingParent, outerTilingParent.layout == .tiles {
            self.outerChildWeights = outerParent.children.map { $0.getWeight(outerTilingParent.orientation) }
        } else {
            self.outerChildWeights = nil
        }
    }

    @MainActor
    func restore(
        parent: NonLeafTreeNodeObject,
        remainingChildren: [TreeNode],
        remainingChildWeights: [CGFloat],
        workspace: Workspace,
    ) -> Bool {
        let outerParent = outerBinding.parent
        guard let parent = parent as? TilingContainer,
              parent.children.isEmpty,
              remainingChildren.count == 1,
              remainingChildWeights.count == 1,
              outerParent is Workspace || outerParent.isBound,
              outerParent.nodeWorkspace === workspace
        else { return false }
        if let outerParent = outerParent as? TilingContainer {
            guard outerParent.layout == layout, outerParent.orientation == orientation else { return false }
        } else {
            guard outerParent === workspace else { return false }
        }

        // normalizeContainers replaces a single-child tiling parent with its child.
        let expectedChildren = outerChildren.flatMap { child in
            child === parent ? remainingChildren : [child]
        }
        guard outerParent.children.count == expectedChildren.count,
              zip(outerParent.children, expectedChildren).allSatisfy({ $0 === $1 })
        else { return false }

        if let outerChildWeights, let orientation {
            let expectedWeights = zip(outerChildren, outerChildWeights).flatMap { child, weight in
                child === parent ? [outerBinding.adaptiveWeight] : [weight]
            }
            let firstDelta = outerParent.children[0].getWeight(orientation) - expectedWeights[0]
            guard zip(outerParent.children, expectedWeights).allSatisfy({ child, expectedWeight in
                abs(child.getWeight(orientation) - expectedWeight - firstDelta) < 0.001
            }) else { return false }
        }

        parent.bind(to: outerBinding.parent, adaptiveWeight: outerBinding.adaptiveWeight, index: outerBinding.index)
        remainingChildren[0].bind(to: parent, adaptiveWeight: remainingChildWeights[0], index: 0)
        if let outerChildWeights, let orientation {
            for (child, weight) in zip(outerChildren, outerChildWeights) {
                child.setWeight(orientation, weight)
            }
        }
        return true
    }
}

private struct MacosNativeFullscreenRestorePoint {
    let binding: BindingData
    let siblings: [TreeNode]
    let layout: Layout?
    let orientation: Orientation?
    let siblingWeights: [CGFloat]?
    let siblingAdaptiveWeights: [CGFloat]
    let flattenedParent: FlattenedParentRestorePoint?

    @MainActor
    init(binding: BindingData) {
        self.binding = binding
        self.siblings = binding.parent.children
        let tilingParent = binding.parent as? TilingContainer
        self.layout = tilingParent?.layout
        self.orientation = tilingParent?.orientation
        let siblingAdaptiveWeights = tilingParent.map { parent in
            binding.parent.children.map { $0.getWeight(parent.orientation) }
        } ?? []
        self.siblingAdaptiveWeights = siblingAdaptiveWeights
        if let tilingParent, tilingParent.layout == .tiles {
            self.siblingWeights = siblingAdaptiveWeights
        } else {
            self.siblingWeights = nil
        }
        self.flattenedParent = FlattenedParentRestorePoint(parent: binding.parent)
    }

    @MainActor
    func restore(window: Window, workspace: Workspace) -> Bool {
        let parent = binding.parent
        guard window.parent === workspace.macOsNativeFullscreenWindowsContainer else { return false }
        if !parent.isBound {
            guard flattenedParent?.restore(
                parent: parent,
                remainingChildren: siblings,
                remainingChildWeights: siblingAdaptiveWeights,
                workspace: workspace,
            ) == true else { return false }
        }
        guard parent.isBound,
              parent.nodeWorkspace === workspace,
              parent.children.count == siblings.count,
              zip(parent.children, siblings).allSatisfy({ $0 === $1 })
        else { return false }

        if let tilingParent = parent as? TilingContainer {
            guard tilingParent.layout == layout, tilingParent.orientation == orientation else { return false }
            if let siblingWeights, let firstSavedWeight = siblingWeights.first {
                let firstDelta = tilingParent.children[0].getWeight(tilingParent.orientation) - firstSavedWeight
                guard zip(tilingParent.children, siblingWeights).allSatisfy({ child, savedWeight in
                    abs(child.getWeight(tilingParent.orientation) - savedWeight - firstDelta) < 0.001
                }) else { return false }
                for (child, savedWeight) in zip(tilingParent.children, siblingWeights) {
                    child.setWeight(tilingParent.orientation, savedWeight)
                }
            }
        }

        window.bind(to: parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
        return true
    }
}

@MainActor
func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: focus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor
private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        let popup = (node as! MacWindow)
        let windowLevel = getWindowLevel(for: popup.windowId)
        if try await popup.isWindowHeuristic(windowLevel, .cancellable) {
            try await popup.relayoutWindow(on: focus.workspace, .cancellable)
            await tryOnWindowDetected(popup)
        }
    }
}

@MainActor
private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    for window in windows {
        let isMacosFullscreen = try await window.isMacosFullscreen(.cancellable)
        let isMacosMinimized = try await (!isMacosFullscreen).andAsync { @MainActor @Sendable in try await window.isMacosMinimized(.cancellable) }
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        switch window.layoutReason {
            case .standard:
                guard let parent = window.parent else { continue }
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

@MainActor
func enterMacOsNativeFullscreen(window: Window, workspace: Workspace) {
    guard let parent = window.parent else { return }
    window.layoutReason = .macos(prevParentKind: parent.kind)
    let binding = window.bind(
        to: workspace.macOsNativeFullscreenWindowsContainer,
        adaptiveWeight: WEIGHT_DOESNT_MATTER,
        index: INDEX_BIND_LAST,
    ).orDie()
    window.putUserData(
        key: macosNativeFullscreenRestorePointKey,
        data: MacosNativeFullscreenRestorePoint(binding: binding),
    )
}

@MainActor
func exitMacOsNativeUnconventionalState(
    window: Window,
    prevParentKind: NonLeafTreeNodeKind,
    workspace: Workspace,
    _ cm: CancellationMode,
) async throws {
    window.layoutReason = .standard
    if window.cleanUserData(key: macosNativeFullscreenRestorePointKey)?.restore(window: window, workspace: workspace) == true {
        return
    }
    switch prevParentKind {
        case .floatingWindowsContainer:
            window.bindAsFloatingWindow(to: workspace)
        case .workspace:
            break // Not possible
        case .tilingContainer:
            try await window.relayoutWindow(on: workspace, cm, forceTile: true)
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            try await window.relayoutWindow(on: workspace, cm)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            try await window.relayoutWindow(on: workspace, cm)
    }
}
