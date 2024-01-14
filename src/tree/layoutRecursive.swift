extension TreeNode {
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect) {
        var point = point
        if let orientation = (self as? TilingContainer)?.orientation, orientation == (parent as? TilingContainer)?.orientation {
            point = orientation == .h
                ? point + CGPoint(x: 0, y: config.indentForNestedContainersWithTheSameOrientation)
                : point + CGPoint(x: config.indentForNestedContainersWithTheSameOrientation, y: 0)
        }
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch genericKind {
        case .workspace(let workspace):
            lastAppliedLayoutPhysicalRect = physicalRect
            lastAppliedLayoutVirtualRect = virtual
            workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual)
            for window in workspace.children.filterIsInstance(of: Window.self) {
                window.layoutFloatingWindow()
            }
        case .window(let window):
            if window.windowId != currentlyManipulatedWithMouseWindowId {
                lastAppliedLayoutVirtualRect = virtual
                if window.isFullscreen && window == workspace.rootTilingContainer.mostRecentWindow {
                    lastAppliedLayoutPhysicalRect = nil
                    window.layoutFullscreen()
                } else {
                    lastAppliedLayoutPhysicalRect = physicalRect
                    window.isFullscreen = false
                    window.setTopLeftCorner(point)
                    window.setSize(CGSize(width: width, height: height))
                }
            }
        case .tilingContainer(let container):
            lastAppliedLayoutPhysicalRect = physicalRect
            lastAppliedLayoutVirtualRect = virtual
            switch container.layout {
            case .tiles:
                container.layoutTiles(point, width: width, height: height, virtual: virtual)
            case .accordion:
                container.layoutAccordion(point, width: width, height: height, virtual: virtual)
            }
        }
    }
}

private extension Window {
    func layoutFloatingWindow() {
        let currentMonitor = getCenter()?.monitorApproximation
        if let currentMonitor, let windowTopLeftCorner = getTopLeftCorner(), workspace != currentMonitor.activeWorkspace {
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let moveTo = workspace.monitor
            setTopLeftCorner(CGPoint(
                x: moveTo.visibleRect.topLeftX + xProportion * moveTo.visibleRect.width,
                y: moveTo.visibleRect.topLeftY + yProportion * moveTo.visibleRect.height
            ))
        }
        if isFullscreen {
            layoutFullscreen()
            isFullscreen = false
        }
    }

    func layoutFullscreen() {
        let monitorRect = workspace.monitor.visibleRectPaddedByOuterGaps
        setTopLeftCorner(monitorRect.topLeftCorner)
        setSize(CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

private extension TilingContainer {
    func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect) {
        let monitor = monitors.first { $0.rect.contains(point) }
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: monitor)
        var point = point
        var virtualPoint = virtual.topLeftCorner

        guard let delta = ((orientation == .h ? width : height) - children.sumOf { $0.getWeight(orientation) })
            .div(children.count) else { return }

        let lastIndex = children.indices.last
        for (i, child) in children.enumerated() {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            let rawGap = gaps.inner.get(orientation).toDouble()
            // Gaps. Consider 4 cases:
            // 1. Multiple children. Layout first child
            // 2. Multiple children. Layout last child
            // 3. Multiple children. Layout child in the middle
            // 4. Single child   let rawGap = gaps.inner.get(orientation).toDouble()
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0)
            child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width:  orientation == .h ? child.hWeight - gap : width,
                height: orientation == .v ? child.vWeight - gap : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width:  orientation == .h ? child.hWeight : width,
                    height: orientation == .v ? child.vWeight : height
                )
            )
            virtualPoint = orientation == .h ? virtualPoint.addingXOffset(child.hWeight) : virtualPoint.addingYOffset(child.vWeight)
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect) {
        guard let mruIndex: Int = mostRecentChild?.ownIndexOrNil else { return }
        for (index, child) in children.enumerated() {
            let lPadding: CGFloat
            let rPadding: CGFloat
            let padding = CGFloat(config.accordionPadding)
            if index == 0 && children.count == 1 {
                lPadding = 0
                rPadding = 0
            } else if index == 0 {
                lPadding = 0
                rPadding = padding
            } else if index == children.indices.last {
                lPadding = padding
                rPadding = 0
            } else if index + 1 == mruIndex {
                lPadding = 0
                rPadding = 2 * padding
            } else if index - 1 == mruIndex {
                lPadding = 2 * padding
                rPadding = 0
            } else {
                lPadding = padding
                rPadding = padding
            }
            switch orientation {
            case .h:
                child.layoutRecursive(
                    point + CGPoint(x: lPadding, y: 0),
                    width: width - rPadding - lPadding,
                    height: height,
                    virtual: virtual
                )
            case .v:
                child.layoutRecursive(
                    point + CGPoint(x: 0, y: lPadding),
                    width: width,
                    height: height - lPadding - rPadding,
                    virtual: virtual
                )
            }
        }
    }
}
