import AppKit

extension Workspace {
    @MainActor
    func layoutWorkspace() async throws -> [TabHeaderSnapshot] {
        if isEffectivelyEmpty { return [] }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        let context = LayoutContext(self)
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, context)
        return context.tabHeaderSnapshots
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
                    let previousPhysicalRect = lastAppliedLayoutPhysicalRect
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive {
                        lastAppliedLayoutPhysicalRect = nil
                        window.isHiddenForTabs = false
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        let wasHiddenForTabs = window.isHiddenForTabs
                        window.isHiddenForTabs = false
                        if wasHiddenForTabs || !rectEquals(previousPhysicalRect, physicalRect) {
                            window.setAxFrame(point, CGSize(width: width, height: height))
                        }
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
                    case .scrolling:
                        try await container.layoutScrolling(point, width: width, height: height, virtual: virtual, context)
                    case .tabs:
                        try await container.layoutTabs(point, width: width, height: height, virtual: virtual, context)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

private func rectEquals(_ lhs: Rect?, _ rhs: Rect) -> Bool {
    guard let lhs else { return false }
    return lhs.topLeftX == rhs.topLeftX &&
        lhs.topLeftY == rhs.topLeftY &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height
}

extension Window {
    static let tabsHiddenPoint = CGPoint(x: -20000, y: -20000)

    @MainActor
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let windowRect = try await getAxRect() // Probably not idempotent
        let currentMonitor = windowRect?.center.monitorApproximation
        if let currentMonitor, let windowRect, workspace != currentMonitor.activeWorkspace {
            let windowTopLeftCorner = windowRect.topLeftCorner
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let workspaceRect = workspace.workspaceMonitor.visibleRect
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
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }

    @MainActor
    fileprivate func hideForTabs() {
        if isHiddenForTabs { return }
        let size = lastAppliedLayoutPhysicalRect?.size
            ?? lastAppliedLayoutVirtualRect?.size
            ?? lastFloatingSize
            ?? CGSize(width: 1, height: 1)
        lastAppliedLayoutPhysicalRect = nil
        isHiddenForTabs = true
        setAxFrame(Self.tabsHiddenPoint, size)
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
    fileprivate func layoutScrolling(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        clampScrollingIndex()
        switch children.count {
            case 0:
                return
            case 1:
                try await children[0].layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            default:
                let pageWidth = width / 2
                let rawGap = context.resolvedGaps.inner.horizontal.toDouble()
                for (index, child) in children.enumerated() {
                    let virtualX = virtual.topLeftX + CGFloat(index) * pageWidth
                    let physicalX = point.x + CGFloat(index - scrollingIndex) * pageWidth
                    let isLeftVisiblePage = index == scrollingIndex
                    let isRightVisiblePage = index == scrollingIndex + 1
                    let lPadding = isRightVisiblePage ? rawGap / 2 : 0
                    let rPadding = isLeftVisiblePage ? rawGap / 2 : 0
                    try await child.layoutRecursive(
                        CGPoint(x: physicalX + lPadding, y: point.y),
                        width: pageWidth - lPadding - rPadding,
                        height: height,
                        virtual: Rect(topLeftX: virtualX, topLeftY: virtual.topLeftY, width: pageWidth, height: height),
                        context,
                    )
                }
        }
    }

    @MainActor
    fileprivate func layoutTabs(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        guard let activeChild = mostRecentChild ?? children.first else { return }
        let headerHeight = TabHeaderMetrics.height
        let hasVisibleHeader = width >= TabHeaderMetrics.minTabWidth && height > headerHeight + 1
        let headerFrame = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: hasVisibleHeader ? headerHeight : 0)
        if hasVisibleHeader {
            let availableWidth = max(0, width - 2 * TabHeaderMetrics.horizontalPadding)
            let spacingCount = max(0, children.count - 1)
            let itemWidth = max(
                1,
                (availableWidth - CGFloat(spacingCount) * TabHeaderMetrics.itemSpacing) / CGFloat(max(1, children.count)),
            )
            var cursorX = TabHeaderMetrics.horizontalPadding
            var items: [TabHeaderItem] = []
            for (index, child) in children.enumerated() {
                guard let targetWindow = child.tabHeaderTargetWindow(),
                      let title = try await child.tabHeaderTitle()
                else { continue }
                let remaining = max(0, width - cursorX - TabHeaderMetrics.horizontalPadding)
                let currentWidth = min(itemWidth, remaining)
                if currentWidth <= 0 { break }
                let itemFrame = Rect(
                    topLeftX: cursorX,
                    topLeftY: TabHeaderMetrics.verticalPadding,
                    width: currentWidth,
                    height: headerHeight - 2 * TabHeaderMetrics.verticalPadding,
                )
                let closeButtonFrame = Rect(
                    topLeftX: max(
                        itemFrame.minX,
                        itemFrame.maxX - TabHeaderMetrics.closeButtonTrailingInset - TabHeaderMetrics.closeButtonSize,
                    ),
                    topLeftY: itemFrame.topLeftY + (itemFrame.height - TabHeaderMetrics.closeButtonSize) / 2,
                    width: min(TabHeaderMetrics.closeButtonSize, itemFrame.width),
                    height: min(TabHeaderMetrics.closeButtonSize, itemFrame.height),
                )
                let titleMaxX = max(itemFrame.minX, closeButtonFrame.minX - TabHeaderMetrics.closeButtonLeadingSpacing)
                let titleFrame = Rect(
                    topLeftX: itemFrame.topLeftX,
                    topLeftY: itemFrame.topLeftY,
                    width: max(0, titleMaxX - itemFrame.topLeftX),
                    height: itemFrame.height,
                )
                items.append(
                    TabHeaderItem(
                        id: "\(ObjectIdentifier(self).debugDescription)-\(index)-\(targetWindow.windowId)",
                        targetWindow: targetWindow,
                        title: title,
                        frame: itemFrame,
                        titleFrame: titleFrame,
                        closeButtonFrame: closeButtonFrame,
                        isActive: child == activeChild,
                    ),
                )
                cursorX += currentWidth + TabHeaderMetrics.itemSpacing
            }
            if !items.isEmpty {
                context.tabHeaderSnapshots.append(
                    TabHeaderSnapshot(
                        id: ObjectIdentifier(self),
                        headerFrame: headerFrame,
                        items: items,
                    ),
                )
            }
        }
        for child in children where child != activeChild {
            try await child.hideSubtreeForTabs()
        }
        let contentPoint = hasVisibleHeader ? point + CGPoint(x: 0, y: headerHeight) : point
        let contentHeight = hasVisibleHeader ? height - headerHeight : height
        let contentVirtual = hasVisibleHeader
            ? Rect(topLeftX: virtual.topLeftX, topLeftY: virtual.topLeftY + headerHeight, width: virtual.width, height: virtual.height - headerHeight)
            : virtual
        try await activeChild.layoutRecursive(contentPoint, width: width, height: contentHeight, virtual: contentVirtual, context)
    }
}

extension TreeNode {
    @MainActor
    fileprivate func hideSubtreeForTabs() async throws {
        switch nodeCases {
            case .window(let window):
                window.hideForTabs()
            case .tilingContainer(let container):
                container.lastAppliedLayoutPhysicalRect = nil
                for child in container.children {
                    try await child.hideSubtreeForTabs()
                }
            case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return
        }
    }
}
