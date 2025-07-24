import AppKit

extension Workspace {
    @MainActor // todo can be dropped in future Swift versions?
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in mointors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(self))
    }
}

extension TreeNode {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .workspace(let workspace):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                try await workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                for window in workspace.children.filterIsInstance(of: Window.self) {
                    window.lastAppliedLayoutPhysicalRect = nil
                    window.lastAppliedLayoutVirtualRect = nil
                    try await window.layoutFloatingWindow(context)
                }
                workspace.optimalHideCorner = nil
            case .window(let window):
                guard window.windowId != currentlyManipulatedWithMouseWindowId else { return }

                lastAppliedLayoutVirtualRect = virtual

                switch determineWindowLayoutMode(window, context) {
                    case .hiddenInCorner(let corner):
                        lastAppliedLayoutPhysicalRect = nil
                        try await window.hideInCorner(corner, context)
                    case .fullscreen:
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    case .visible:
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        window.shouldHideOthersWhileFullscreen = false
                        window.setAxFrame(point, CGSize(width: width, height: height))
                        window.clearHiddenState()
                }
            case .tilingContainer(let container):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
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

    @MainActor
    init(_ workspace: Workspace) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    }
}

private enum WindowLayoutMode {
    case visible
    case fullscreen
    case hiddenInCorner(OptimalHideCorner)
}

@MainActor
private func determineWindowLayoutMode(_ window: Window, _ context: LayoutContext) -> WindowLayoutMode {
    let workspaceIsHidden = !context.workspace.isVisible
    let mostRecentWindow = context.workspace.rootTilingContainer.mostRecentWindowRecursive
    let windowShouldBeHidden = mostRecentWindow.map {
        window != $0 && $0.isFullscreen && $0.shouldHideOthersWhileFullscreen
    } ?? false

    if workspaceIsHidden || windowShouldBeHidden {
        let corner = context.workspace.optimalHideCorner ?? .bottomRightCorner
        return .hiddenInCorner(corner)
    }

    if window == mostRecentWindow && window.isFullscreen {
        return .fullscreen
    }

    return .visible
}

extension Window {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let currentMonitor = try await getCenter()?.monitorApproximation // Probably not idempotent
        if let currentMonitor, let windowTopLeftCorner = try await getAxTopLeftCorner(), workspace != currentMonitor.activeWorkspace {
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let moveTo = workspace.workspaceMonitor
            setAxTopLeftCorner(CGPoint(
                x: moveTo.visibleRect.topLeftX + xProportion * moveTo.visibleRect.width,
                y: moveTo.visibleRect.topLeftY + yProportion * moveTo.visibleRect.height,
            ))
        }
        if isFullscreen {
            layoutFullscreen(context)
            isFullscreen = false
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }

    @MainActor
    fileprivate func hideInCorner(_ corner: OptimalHideCorner, _ context: LayoutContext) async throws {
        guard let nodeMonitor else { return }
        // Don't accidentally override hiddenState in case of subsequent
        // `hideEmulation` calls
        if !isHiddenInCorner {
            guard let windowRect = try await getAxRect() else { return }
            let topLeftCorner = windowRect.topLeftCorner
            let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
            let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
            let proportionalPosition = CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
            setHiddenState(proportionalPosition)
        }
        let p: CGPoint
        let offset = getCornerOffsetWhileHidden(corner)
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getAxSize() else { fallthrough }
                p = nodeMonitor.visibleRect.bottomLeftCorner + offset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                p = nodeMonitor.visibleRect.bottomRightCorner + offset
        }
        setAxTopLeftCorner(p)
    }
}

extension TilingContainer {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        var point = point
        var virtualPoint = virtual.topLeftCorner

        guard let delta = ((orientation == .h ? width : height) - CGFloat(children.sumOfDouble { $0.getWeight(orientation) }))
            .div(children.count) else { return }

        let lastIndex = children.indices.last
        for (i, child) in children.enumerated() {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            let rawGap = context.resolvedGaps.inner.get(orientation).toDouble()
            // Gaps. Consider 4 cases:
            // 1. Multiple children. Layout first child
            // 2. Multiple children. Layout last child
            // 3. Multiple children. Layout child in the middle
            // 4. Single child   let rawGap = gaps.inner.get(orientation).toDouble()
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0)
            try await child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width: orientation == .h ? child.hWeight - gap : width,
                height: orientation == .v ? child.vWeight - gap : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width: orientation == .h ? child.hWeight : width,
                    height: orientation == .v ? child.vWeight : height,
                ),
                context,
            )
            virtualPoint = orientation == .h ? virtualPoint.addingXOffset(child.hWeight) : virtualPoint.addingYOffset(child.vWeight)
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        guard let mruIndex: Int = mostRecentChild?.ownIndex else { return }
        for (index, child) in children.enumerated() {
            let padding = CGFloat(config.accordionPadding)
            let (lPadding, rPadding): (CGFloat, CGFloat) = switch index {
                case 0 where children.count == 1: (0, 0)
                case 0:                           (0, padding)
                case children.indices.last:       (padding, 0)
                case mruIndex - 1:                (0, 2 * padding)
                case mruIndex + 1:                (2 * padding, 0)
                default:                          (padding, padding)
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
