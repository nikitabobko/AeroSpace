import AppKit
import Common

@MainActor
private var moveWithMouseTask: Task<(), any Error>? = nil

func movedObs(_: AXObserver, ax: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let windowId = ax.containingWindowId()
    let notif = notif as String
    Task.startUnstructured { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            scheduleCancellableCompleteRefreshSession(.ax(notif))
            return
        }
        moveWithMouseTask?.cancel()
        moveWithMouseTask = Task.startUnstructured {
            try checkCancellation()
            try await runLightSession(.ax(notif), token) {
                try await moveWithMouse(window)
            }
        }
    }
}

@MainActor
private func moveWithMouse(_ window: Window) async throws { // todo cover with tests
    resetClosedWindowsCache()
    switch window.windowParentCases {
        case .floatingWindowsContainer:
            try await moveFloatingWindow(window)
        case .macosFullscreenWindowsContainer, .macosMinimizedWindowsContainer, .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return // Unconventional windows can't be moved with mouse
        case .tilingContainer:
            moveTilingWindow(window)
        case .unbound: return
    }
}

@MainActor
private func moveFloatingWindow(_ window: Window) async throws {
    guard let targetWorkspace = try await window.getCenter(.cancellable)?.monitorApproximation.activeWorkspace else { return }
    guard let parent = window.parent else { return }
    if targetWorkspace != parent {
        window.bindAsFloatingWindow(to: targetWorkspace)
    }
}

/// enable-auto-tiling. The tiling window that is being dragged with mouse. The tree is changed once the window is dropped
@MainActor private var draggedTilingWindowId: UInt32? = nil
/// Dragging the left/top border of the window also moves the window. It's a resize, not a move
@MainActor var isMouseManipulationResize: Bool = false

/// The part of the tile (on each side) that splits the tile when a window is dropped onto it.
/// The center of the tile swaps the windows
private let dropSplitZone: CGFloat = 0.3

@MainActor
func dropDraggedTilingWindowIfNeeded() {
    defer {
        draggedTilingWindowId = nil
        isMouseManipulationResize = false
    }
    guard config.enableAutoTiling, !isMouseManipulationResize,
          let windowId = draggedTilingWindowId, let window = Window.get(byId: windowId), window.parent is TilingContainer
    else { return }
    let mouseLocation = mouseLocation
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    let target = mouseLocation
        .findWindowRecursively(in: targetWorkspace.rootTilingContainer, virtual: false, fullscreenCoversAll: false)?
        .takeIf { $0 != window }
    if let target {
        dropTilingWindow(window, onto: target, at: mouseLocation)
    } else if targetWorkspace != window.nodeWorkspace { // Dropped onto an empty space of a different monitor
        window.unbindFromParent()
        let data = targetWorkspace.prepareTilingWindowInsertion(autoTile: true)
        window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

/// - The center of the target swaps the windows
/// - The sides of the target split the target. The dropped window takes the half where it was dropped
@MainActor
func dropTilingWindow(_ window: Window, onto target: Window, at point: CGPoint) {
    guard window != target, let rect = target.lastAppliedLayoutPhysicalRect, rect.width > 0 && rect.height > 0 else { return }
    let x = (point.x - rect.minX) / rect.width
    let y = (point.y - rect.minY) / rect.height
    let sides: [(distance: CGFloat, orientation: Orientation, insertBefore: Bool)] = [
        (x, .h, true), (1 - x, .h, false), (y, .v, true), (1 - y, .v, false),
    ]
    guard let side = sides.min(by: { $0.distance < $1.distance }), side.distance < dropSplitZone,
          (target.parent as? TilingContainer)?.layout == .tiles
    else {
        swapWindows(mruDominant: window, target)
        return
    }
    window.unbindFromParent() // Unbind first. The window and the target might be siblings
    guard let data = target.prepareSplit(side.orientation, insertBefore: side.insertBefore) else { return }
    window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
}

@MainActor
private func moveTilingWindow(_ window: Window) {
    currentlyManipulatedWithMouseWindowId = window.windowId
    window.lastAppliedLayoutPhysicalRect = nil
    if config.enableAutoTiling { // The tree is changed once the window is dropped
        draggedTilingWindowId = window.windowId
        return
    }
    let mouseLocation = mouseLocation
    let targetWorkspace = mouseLocation.monitorApproximation.activeWorkspace
    let swapTarget = mouseLocation
        .findWindowRecursively(in: targetWorkspace.rootTilingContainer, virtual: false, fullscreenCoversAll: false)?
        .takeIf { $0 != window }
    if targetWorkspace != window.nodeWorkspace { // Move window to a different monitor
        let index: Int = if let swapTarget, let parent = swapTarget.parent as? TilingContainer, let targetRect = swapTarget.lastAppliedLayoutPhysicalRect {
            mouseLocation.getProjection(parent.orientation) >= targetRect.center.getProjection(parent.orientation)
                ? swapTarget.ownIndex.orDie() + 1
                : swapTarget.ownIndex.orDie()
        } else {
            0
        }
        window.bind(
            to: swapTarget?.parent ?? targetWorkspace.rootTilingContainer,
            adaptiveWeight: WEIGHT_AUTO,
            index: index,
        )
    } else if let swapTarget {
        swapWindows(mruDominant: window, swapTarget)
    }
}

@MainActor
func swapWindows(mruDominant window1: Window, _ window2: Window) {
    if window1 == window2 { return }

    let binding2 = window2.unbindFromParent()
    let binding1 = window1.unbindFromParent()

    window2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
    window1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
}

extension CGPoint {
    @MainActor
    func findWindowRecursively(
        in tree: TilingContainer,
        virtual: Bool,
        fullscreenCoversAll: Bool,
    ) -> Window? {
        if fullscreenCoversAll {
            if let window = tree.mostRecentWindowRecursive, window.isFullscreen {
                return window
            }
        }
        return _findWindowRecursively(in: tree, virtual: virtual)
    }

    @MainActor
    private func _findWindowRecursively(in tree: TilingContainer, virtual: Bool) -> Window? {
        let point = self
        let target: TreeNode? = switch tree.layout {
            case .tiles:
                tree.children.first(where: {
                    (virtual ? $0.lastAppliedLayoutVirtualRect : $0.lastAppliedLayoutPhysicalRect)?.contains(point) == true
                })
            case .accordion:
                tree.mostRecentChild
        }
        guard let target else { return nil }
        return switch target.tilingTreeNodeCasesOrDie() {
            case .window(let window): window
            case .tilingContainer(let container): _findWindowRecursively(in: container, virtual: virtual)
        }
    }
}
