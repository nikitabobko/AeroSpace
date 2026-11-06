import AppKit
import Common

extension Workspace {
    @MainActor
    func layoutWorkspace() async throws { // todo revisit API
        try await layoutWorkspace(LayoutContext(self, measurement: nil))
    }

    /// Dry run of ``layoutWorkspace()``.
    /// It computes the rects that the layout would apply to the tree, but it doesn't touch the AX API and it
    /// doesn't mutate the tree. Works for invisible workspaces too
    @MainActor
    func measureLayout() async throws -> LayoutMeasurement {
        let measurement = LayoutMeasurement()
        try await layoutWorkspace(LayoutContext(self, measurement: measurement))
        return measurement
    }

    @MainActor
    private func layoutWorkspace(_ context: LayoutContext) async throws {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, context)
    }
}

/// Rects that ``Workspace/layoutWorkspace()`` would apply to the nodes of the tree. See ``Workspace/measureLayout()``
final class LayoutMeasurement {
    private var rects: [ObjectIdentifier: Rect] = [:]

    func rect(of node: TreeNode) -> Rect? { rects[ObjectIdentifier(node)] }
    fileprivate func put(_ node: TreeNode, _ rect: Rect) { rects[ObjectIdentifier(node)] = rect }
}

extension TreeNode {
    @MainActor
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .monitor(let it):
                try await it.getWorkspacesContainerOrCreate().getVisibleWorkspaceOrCreate(parent: it)
                    .layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            case .workspacesContainer: die()
            case .workspace(let workspace):
                if let measurement = context.measurement {
                    measurement.put(self, physicalRect)
                } else {
                    lastAppliedLayoutPhysicalRect = physicalRect
                    lastAppliedLayoutVirtualRect = virtual
                }
                try await workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                try await workspace.floatingWindowsContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            case .floatingWindowsContainer(let container):
                if context.measurement != nil { return } // Floating windows are not laid out by the tree
                let windows = container.children.filterIsInstance(of: Window.self)
                // todo make it parallel among different workspaces. Get rid of 'try await'
                let rects = try await windows.mapConcurrently { try await $0.getAxRect(.cancellable) } // Probably not idempotent
                for (window, windowRect) in zip(windows, rects) {
                    window.lastAppliedLayoutPhysicalRect = nil
                    window.lastAppliedLayoutVirtualRect = nil
                    window.layoutFloatingWindow(context, windowRect)
                }
            case .window(let window):
                let isFullscreen = window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive
                if let measurement = context.measurement {
                    measurement.put(self, isFullscreen ? window.fullscreenRect(context) : physicalRect)
                } else if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if isFullscreen {
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        window.setAxFrame(point, CGSize(width: width, height: height))
                    }
                }
            case .tilingContainer(let container):
                if let measurement = context.measurement {
                    measurement.put(self, physicalRect)
                } else {
                    lastAppliedLayoutPhysicalRect = physicalRect
                    lastAppliedLayoutVirtualRect = virtual
                }
                switch container.layout {
                    case .tiles:
                        try await container.layoutTiles(point, width: width, height: height, virtual: virtual, context)
                    case .accordion:
                        try await container.layoutAccordion(point, width: width, height: height, virtual: virtual, context)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

private struct LayoutContext {
    let workspace: Workspace
    let resolvedGaps: ResolvedGaps
    /// nil means that the layout is applied. Otherwise, the layout is only measured (dry run)
    let measurement: LayoutMeasurement?

    @MainActor
    init(_ workspace: Workspace, measurement: LayoutMeasurement?) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitorInfo)
        self.measurement = measurement
    }
}

extension Window {
    @MainActor
    fileprivate func layoutFloatingWindow(_ context: LayoutContext, _ windowRect: Rect?) {
        let workspace = context.workspace
        let currentMonitor = windowRect?.center.monitorApproximation
        if let currentMonitor, let windowRect, workspace != currentMonitor.visibleWorkspace {
            let windowTopLeftCorner = windowRect.topLeftCorner
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let workspaceRect = workspace.workspaceMonitorInfo.visibleRect
            var newX = workspaceRect.topLeftX + xProportion * workspaceRect.width
            var newY = workspaceRect.topLeftY + yProportion * workspaceRect.height

            let windowWidth = windowRect.width
            let windowHeight = windowRect.height
            newX = newX.coerce(in: workspaceRect.minX ... max(workspaceRect.minX, workspaceRect.maxX - windowWidth))
            newY = newY.coerce(in: workspaceRect.minY ... max(workspaceRect.minY, workspaceRect.maxY - windowHeight))

            setAxFrame(CGPoint(x: newX, y: newY), nil)
        }
        if isFullscreen {
            layoutFullscreen(context)
            isFullscreen = false
        }
    }

    @MainActor
    fileprivate func fullscreenRect(_ context: LayoutContext) -> Rect {
        noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitorInfo.visibleRect
            : context.workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
    }

    @MainActor
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = fullscreenRect(context)
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

extension TilingContainer {
    @MainActor
    fileprivate func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        var point = point
        var virtualPoint = virtual.topLeftCorner

        let inhabitedChildren = inhabitedChildren

        guard let delta = ((orientation == .h ? width : height) - CGFloat(inhabitedChildren.sumOfDouble { $0.getWeight(orientation) }))
            .div(inhabitedChildren.count) else { return }

        let lastIndex = inhabitedChildren.indices.last
        for (i, child) in inhabitedChildren.enumerated() {
            let weight = child.getWeight(orientation) + delta
            if context.measurement == nil {
                child.setWeight(orientation, weight)
            }
            let rawGap = context.resolvedGaps.inner.get(orientation).toDouble()
            // Gaps. Consider 4 cases:
            // 1. Multiple children. Layout first child
            // 2. Multiple children. Layout last child
            // 3. Multiple children. Layout child in the middle
            // 4. Single child   let rawGap = gaps.inner.get(orientation).toDouble()
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0)
            try await child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width: orientation == .h ? weight - gap : width,
                height: orientation == .v ? weight - gap : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width: orientation == .h ? weight : width,
                    height: orientation == .v ? weight : height,
                ),
                context,
            )
            virtualPoint = orientation == .h ? virtualPoint.addingXOffset(weight) : virtualPoint.addingYOffset(weight)
            point = orientation == .h ? point.addingXOffset(weight) : point.addingYOffset(weight)
        }
    }

    @MainActor
    fileprivate func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let inhabitedChildren = inhabitedChildren

        guard let mruIndex: Int = mostRecentInhabitedChild?.ownIndex(in: .inhabitedOnly) else { return }
        for (index, child) in inhabitedChildren.enumerated() {
            let padding = CGFloat(config.accordionPadding)
            let (lPadding, rPadding): (CGFloat, CGFloat) = switch index {
                case 0 where inhabitedChildren.count == 1: (0, 0)
                case 0:                                (0, padding)
                case inhabitedChildren.indices.last:   (padding, 0)
                case mruIndex - 1:                     (0, 2 * padding)
                case mruIndex + 1:                     (2 * padding, 0)
                default:                               (padding, padding)
            }
            switch orientation {
                case .h:
                    try await child.layoutRecursive(
                        point + CGPoint(x: lPadding, y: 0),
                        width: width - rPadding - lPadding,
                        height: height,
                        virtual: virtual,
                        context,
                    )
                case .v:
                    try await child.layoutRecursive(
                        point + CGPoint(x: 0, y: lPadding),
                        width: width,
                        height: height - lPadding - rPadding,
                        virtual: virtual,
                        context,
                    )
            }
        }
    }
}
