import AppKit

extension Workspace {
    @MainActor // todo can be dropped in future Swift versions?
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty { return }

        // Create LayoutContext first to get correct gaps including single-window adjustments
        let context = LayoutContext(self)
        let baseRect = workspaceMonitor.visibleRect
        let rect = context.resolvedGaps.applyToRect(baseRect)

        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in mointors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, context)
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
            case .window(let window):
                if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive {
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.setAxFrame(point, CGSize(width: width, height: height))
                    }
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
        let singleWindowSideGap = Self.calculateSingleWindowSideGap(for: workspace)
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor, singleWindowSideGap: singleWindowSideGap)
    }

    @MainActor
    init(_ workspace: Workspace, forceFullscreenAsSingleWindow fullscreenWindow: Window) {
        self.workspace = workspace
        let singleWindowSideGap = Self.calculateSingleWindowSideGap(for: workspace, forceFullscreenAsSingleWindow: fullscreenWindow)
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor, singleWindowSideGap: singleWindowSideGap)
    }

    @MainActor
    private static func calculateSingleWindowSideGap(for workspace: Workspace, forceFullscreenAsSingleWindow fullscreenWindow: Window? = nil) -> Int {
        let windowCount = workspace.rootTilingContainer.allLeafWindowsRecursive.count

        guard let window = getEffectiveWindow(workspace: workspace, fullscreenOverride: fullscreenWindow) else {
            return 0
        }

        guard shouldApplySingleWindowConstraints(window: window, windowCount: windowCount, fullscreenOverride: fullscreenWindow) else {
            return 0
        }

        return calculateSideGapForWindow(window, monitor: workspace.workspaceMonitor)
    }

    @MainActor
    private static func getEffectiveWindow(workspace: Workspace, fullscreenOverride: Window?) -> Window? {
        if let fullscreenWindow = fullscreenOverride {
            // For fullscreen windows, treat as single window regardless of actual count
            return fullscreenWindow
        } else {
            // Normal behavior: only apply single-window logic when there's exactly one window
            let windowCount = workspace.rootTilingContainer.allLeafWindowsRecursive.count
            guard windowCount == 1,
                  let singleWindow = workspace.rootTilingContainer.allLeafWindowsRecursive.first
            else {
                return nil
            }
            return singleWindow
        }
    }

    @MainActor
    private static func shouldApplySingleWindowConstraints(window: Window, windowCount: Int, fullscreenOverride: Window?) -> Bool {
        // Check if this window has --no-max-width flag set for fullscreen
        if window.noMaxWidthInFullscreen && window.isFullscreen {
            return false
        }

        // Check if app is excluded from width limiting
        let appId = window.app.bundleId ?? ""
        let isExcluded = config.singleWindowExcludeAppIds.contains(appId)

        return !isExcluded
    }

    @MainActor
    private static func calculateSideGapForWindow(_ window: Window, monitor: any Monitor) -> Int {
        let maxWidthPercent = config.singleWindowMaxWidthPercent.getValue(for: monitor)

        guard maxWidthPercent < 100 else { return 0 }

        let totalWidth = monitor.visibleRect.width
        let maxWidth = totalWidth * Double(maxWidthPercent) / 100.0
        return Int((totalWidth - maxWidth) / 2.0)
    }
}

extension Window {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let currentMonitor = try await getCenter()?.monitorApproximation
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
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : {
                // Avoid potential infinite recursion when dealing with excluded apps
                // by reusing existing gaps if they were already calculated for this window
                let fullscreenContext = LayoutContext(context.workspace, forceFullscreenAsSingleWindow: self)
                return fullscreenContext.resolvedGaps.applyToRect(context.workspace.workspaceMonitor.visibleRect)
            }()
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
        lastAppliedLayoutPhysicalRect = Rect(
            topLeftX: monitorRect.topLeftX,
            topLeftY: monitorRect.topLeftY,
            width: monitorRect.width,
            height: monitorRect.height,
        )
    }
}

extension TilingContainer {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        var point = point
        var virtualPoint = virtual.topLeftCorner

        guard let delta = ((orientation == .h ? width : height) - CGFloat(children.sumOf { $0.getWeight(orientation) }))
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
