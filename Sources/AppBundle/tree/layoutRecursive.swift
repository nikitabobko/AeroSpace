import AppKit
extension Workspace {
    func layoutWorkspace() {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in mointors horizontal configuration. ¯\_(ツ)_/¯
        layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(workspace: self))
    }
}

private extension TreeNode {
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .workspace(let workspace):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                for window in workspace.children.filterIsInstance(of: Window.self) {
                    window.layoutFloatingWindow(context)
                }
            case .window(let window):
                if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindow {
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        _ = window.setFrame(point, CGSize(width: width, height: height))
                    }
                }
            case .tilingContainer(let container):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                switch container.layout {
                    case .tiles:
                        container.layoutTiles(point, width: width, height: height, virtual: virtual, context)
                    case .accordion:
                        container.layoutAccordion(point, width: width, height: height, virtual: virtual, context)
                }
            case .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer, .macosPopupWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

private struct LayoutContext {
    let workspace: Workspace
}

private extension Window {
    func layoutFloatingWindow(_ context: LayoutContext) {
        let workspace = context.workspace
        let currentMonitor = getCenter()?.monitorApproximation
        if let currentMonitor, let windowTopLeftCorner = getTopLeftCorner(), workspace != currentMonitor.activeWorkspace {
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let moveTo = workspace.workspaceMonitor
            _ = setTopLeftCorner(CGPoint(
                x: moveTo.visibleRect.topLeftX + xProportion * moveTo.visibleRect.width,
                y: moveTo.visibleRect.topLeftY + yProportion * moveTo.visibleRect.height
            ))
        }
        if isFullscreen {
            layoutFullscreen(context)
            isFullscreen = false
        }
    }

    func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        _ = setFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

private extension TilingContainer {
    func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) {
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: context.workspace.workspaceMonitor)
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
                width: orientation == .h ? child.hWeight - gap : width,
                height: orientation == .v ? child.vWeight - gap : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width: orientation == .h ? child.hWeight : width,
                    height: orientation == .v ? child.vWeight : height
                ),
                context
            )
            virtualPoint = orientation == .h ? virtualPoint.addingXOffset(child.hWeight) : virtualPoint.addingYOffset(child.vWeight)
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) {
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
                        virtual: virtual,
                        context
                    )
                case .v:
                    child.layoutRecursive(
                        point + CGPoint(x: 0, y: lPadding),
                        width: width,
                        height: height - lPadding - rPadding,
                        virtual: virtual,
                        context
                    )
            }
        }
    }
}
