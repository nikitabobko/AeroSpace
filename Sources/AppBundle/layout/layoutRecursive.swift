import AppKit
import Common

extension Workspace {
    @MainActor
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(self))
    }
}

extension TreeNode {
    @MainActor
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
                        window.isFullscreen = false
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
                    case .dwindle:
                        try await container.layoutDwindle(point, width: width, height: height, virtual: virtual, context)
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

extension Window {
    @MainActor
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

    @MainActor
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

extension TilingContainer {
    @MainActor
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

    @MainActor
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

    @MainActor
    fileprivate func layoutDwindle(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        // Dwindle layout uses a binary tree approach, respecting container orientation and node weights
        guard !children.isEmpty else { return }

        if children.count == 1 {
            // Single child takes full space
            try await children[0].layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            return
        }

        // For multiple children, we need to create a binary tree structure
        // We'll split the container and assign children to left/right or top/bottom
        try await layoutDwindleRecursive(children, orientation: orientation, point: point, width: width, height: height, virtual: virtual, context: context)
    }

    @MainActor
    private func layoutDwindleRecursive(_ nodes: [TreeNode], orientation: Orientation, point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, context: LayoutContext) async throws {
        guard !nodes.isEmpty else { return }

        if nodes.count == 1 {
            // Single node takes full space
            try await nodes[0].layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            return
        }

        // Determine split direction based on the container's orientation
        let splitVertically = orientation == .h

        // Get gap size for the split direction
        let gapSize = splitVertically
            ? context.resolvedGaps.inner.horizontal.toDouble()
            : context.resolvedGaps.inner.vertical.toDouble()

        // Calculate midpoint for splitting (binary tree structure)
        let midIndex = nodes.count / 2
        let leftNodes = Array(nodes[0 ..< midIndex])
        let rightNodes = Array(nodes[midIndex...])

        // Calculate split ratio based on node weights
        let totalWeight = CGFloat(nodes.sumOfDouble { $0.getWeight(orientation) })
        let leftWeight = CGFloat(leftNodes.sumOfDouble { $0.getWeight(orientation) })

        // Guard against zero weight - fall back to even split
        let splitRatio: CGFloat = totalWeight > 0 ? leftWeight / totalWeight : 0.5

        // Alternate orientation for recursive splits (creates the dwindle pattern)
        let nextOrientation = orientation.opposite

        if splitVertically {
            // Split left/right with gap
            let totalWidth = width - gapSize
            let leftWidth = totalWidth * splitRatio
            let rightWidth = totalWidth - leftWidth

            // Layout left side
            try await layoutDwindleRecursive(leftNodes, orientation: nextOrientation, point: point, width: leftWidth, height: height,
                                             virtual: Rect(topLeftX: virtual.topLeftX, topLeftY: virtual.topLeftY,
                                                           width: virtual.width * splitRatio, height: virtual.height),
                                             context: context)

            // Layout right side (with gap offset)
            try await layoutDwindleRecursive(rightNodes, orientation: nextOrientation, point: CGPoint(x: point.x + leftWidth + gapSize, y: point.y),
                                             width: rightWidth, height: height,
                                             virtual: Rect(topLeftX: virtual.topLeftX + virtual.width * splitRatio,
                                                           topLeftY: virtual.topLeftY,
                                                           width: virtual.width * (1 - splitRatio), height: virtual.height),
                                             context: context)
        } else {
            // Split top/bottom with gap
            let totalHeight = height - gapSize
            let topHeight = totalHeight * splitRatio
            let bottomHeight = totalHeight - topHeight

            // Layout top side
            try await layoutDwindleRecursive(leftNodes, orientation: nextOrientation, point: point, width: width, height: topHeight,
                                             virtual: Rect(topLeftX: virtual.topLeftX, topLeftY: virtual.topLeftY,
                                                           width: virtual.width, height: virtual.height * splitRatio),
                                             context: context)

            // Layout bottom side (with gap offset)
            try await layoutDwindleRecursive(rightNodes, orientation: nextOrientation, point: CGPoint(x: point.x, y: point.y + topHeight + gapSize),
                                             width: width, height: bottomHeight,
                                             virtual: Rect(topLeftX: virtual.topLeftX,
                                                           topLeftY: virtual.topLeftY + virtual.height * splitRatio,
                                                           width: virtual.width, height: virtual.height * (1 - splitRatio)),
                                             context: context)
        }
    }
}
