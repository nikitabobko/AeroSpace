import AppKit
import Common

@MainActor private var nativeFullscreenSettling: [OpaqueWindowId: NativeFullscreenSettlingState] = [:]

// Keep only the restored split's weights. A late Space visibility update can
// temporarily change its orientation and reinterpret heights as widths.
@MainActor private final class NativeFullscreenSettlingState {
    weak var window: Window?
    weak var parent: TilingContainer?
    let workspace: Workspace
    let ancestors: [NonLeafTreeNodeObject]
    let monitorId: Int
    let orientation: Orientation
    let children: [TreeNode]
    let weights: [CGFloat]
    let visibleWindows: [Window]
    let deadline: ContinuousClock.Instant
    var stableSince: ContinuousClock.Instant?
    var geometry: [CGRect]?

    init(window: Window, parent: TilingContainer, children: [TreeNode], weights: [CGFloat], visibleWindows: [Window], deadline: ContinuousClock.Instant) {
        self.window = window
        self.parent = parent
        workspace = window.nodeWorkspace.orDie()
        ancestors = parent.parents
        monitorId = workspace.workspaceMonitorInfo.monitorAppKitNsScreenScreensId
        orientation = parent.orientation
        self.children = children
        self.weights = weights
        self.visibleWindows = visibleWindows
        self.deadline = deadline
    }

    var isCompatible: Bool {
        guard let window, let parent,
              window.parent === parent, window.layoutReason == .standard, !window.isFullscreen,
              parent.nodeWorkspace === workspace, workspace.isBound, parent.layout == .tiles,
              workspace.workspaceMonitorInfo.monitorAppKitNsScreenScreensId == monitorId,
              parent.children == children, parent.parents.count == ancestors.count,
              zip(parent.parents, ancestors).allSatisfy({ $0 === $1 })
        else { return false }
        return true
    }
}

@MainActor func hasNativeFullscreenSettling(_ window: Window) -> Bool {
    nativeFullscreenSettling[window.windowId] != nil
}

@MainActor func beginNativeFullscreenSettling(
    window: Window, parent: TilingContainer, children: [TreeNode], weights: [CGFloat],
    visibleWindows: [Window], deadline: ContinuousClock.Instant,
) {
    endNativeFullscreenSettling(window)
    guard children.count > 1, deadline > .now else { return }
    nativeFullscreenSettling[window.windowId] = NativeFullscreenSettlingState(
        window: window, parent: parent, children: children, weights: weights,
        visibleWindows: visibleWindows, deadline: deadline,
    )
    requestNativeFullscreenRefresh(for: window)
}

@MainActor func endNativeFullscreenSettling(_ window: Window) {
    if nativeFullscreenSettling.removeValue(forKey: window.windowId) != nil {
        cancelNativeFullscreenRefresh(for: window)
    }
}

@MainActor func invalidateNativeFullscreenSettling() {
    for state in nativeFullscreenSettling.values {
        if let window = state.window { cancelNativeFullscreenRefresh(for: window) }
    }
    nativeFullscreenSettling = [:]
}

// Run after normalization and before layout so invisible or still-settling
// windows cannot permanently change the restored split's proportions.
@MainActor func settleNativeFullscreenRestorations(now: ContinuousClock.Instant = .now) async throws {
    for (id, state) in nativeFullscreenSettling {
        guard state.isCompatible, let window = state.window, let parent = state.parent, now < state.deadline else {
            if let window = state.window { cancelNativeFullscreenRefresh(for: window) }
            nativeFullscreenSettling[id] = nil
            continue
        }
        guard state.visibleWindows.allSatisfy({ $0.lifeStatus == .alive }) else {
            state.stableSince = nil
            state.geometry = nil
            requestNativeFullscreenRefresh(for: window)
            continue
        }
        guard parent.orientation == state.orientation else {
            endNativeFullscreenSettling(window)
            continue
        }

        // Match layoutTiles when the available screen height/width changes. The
        // saved differences are preserved, without fighting its uniform delta.
        let active = state.children.indices.filter { state.children[$0].tilingTreeNodeCasesOrDie().isInhabited }
        let savedLength = active.reduce(CGFloat.zero) { $0 + state.weights[$1] }
        let availableLength = parent.lastAppliedLayoutPhysicalRect?.getDimension(state.orientation) ?? savedLength
        let delta = active.isEmpty ? 0 : (availableLength - savedLength) / CGFloat(active.count)
        let desired = zip(state.children, state.weights).map { child, weight in
            weight + (child.tilingTreeNodeCasesOrDie().isInhabited ? delta : 0)
        }
        let repaired = zip(state.children, desired).contains { abs($0.getWeight(state.orientation) - $1) > 0.001 }
        for (child, weight) in zip(state.children, desired) { child.setWeight(state.orientation, weight) }

        let rects = try await state.visibleWindows.mapConcurrently { try await $0.getAxRect(.cancellable) }
        // AX reads suspend. A command or a new fullscreen cycle may have
        // invalidated this state while the requests were in flight.
        guard nativeFullscreenSettling[id] === state else { continue }
        guard state.isCompatible else {
            endNativeFullscreenSettling(window)
            continue
        }
        let actual = rects.compactMap { $0.map { CGRect(origin: $0.topLeftCorner, size: $0.size) } }
        let expected = state.visibleWindows.compactMap { $0.lastAppliedLayoutPhysicalRect.map { CGRect(origin: $0.topLeftCorner, size: $0.size) } }
        let monitor = state.workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        let geometry = [CGRect(origin: monitor.topLeftCorner, size: monitor.size)] + actual
        let framesMatch = actual.count == state.visibleWindows.count && expected.count == actual.count && framesApproximatelyEqual(actual, expected)
        if repaired || !framesMatch {
            state.stableSince = nil
        } else if state.geometry.map({ framesApproximatelyEqual($0, geometry) }) == true {
            state.stableSince = state.stableSince ?? now
        } else {
            state.stableSince = now
        }
        state.geometry = geometry
        if let since = state.stableSince, since.duration(to: now) >= .milliseconds(300) {
            endNativeFullscreenSettling(window)
        } else {
            requestNativeFullscreenRefresh(for: window)
        }
    }
}

private func framesApproximatelyEqual(_ lhs: [CGRect], _ rhs: [CGRect]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
        abs($0.minX - $1.minX) <= 1 && abs($0.minY - $1.minY) <= 1 &&
            abs($0.width - $1.width) <= 1 && abs($0.height - $1.height) <= 1
    }
}
