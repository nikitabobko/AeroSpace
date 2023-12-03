extension TreeNode {
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, gapless: Rect) {
        var point = point
        if let orientation = (self as? TilingContainer)?.orientation, orientation == (parent as? TilingContainer)?.orientation {
            point = orientation == .h
                ? point + CGPoint(x: 0, y: config.indentForNestedContainersWithTheSameOrientation)
                : point + CGPoint(x: config.indentForNestedContainersWithTheSameOrientation, y: 0)
        }
        switch genericKind {
        case .workspace(let workspace):
            lastAppliedLayoutTilingRectForMouse = gapless
            workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height)
        case .window(let window):
            if window.windowId != currentlyManipulatedWithMouseWindowId {
                lastAppliedLayoutTilingRectForMouse = gapless
                if window.isFullscreen && window == focusedWindow {
                    let monitorRect = window.workspace.monitor.visibleRect
                    window.setTopLeftCorner(monitorRect.topLeftCorner)
                    window.setSize(CGSize(width: monitorRect.width, height: monitorRect.height))
                } else {
                    window.isFullscreen = false
                    window.setTopLeftCorner(point)
                    window.setSize(CGSize(width: width, height: height))
                }
            }
        case .tilingContainer(let container):
            lastAppliedLayoutTilingRectForMouse = gapless
            switch container.layout {
            case .tiles:
                container.layoutTiles(point, width: width, height: height, gapless: gapless)
            case .accordion:
                container.layoutAccordion(point, width: width, height: height, gapless: gapless)
            }
        }
    }
}

private extension TilingContainer {
    func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, gapless: Rect) {
        var point = point
        var gaplessPoint = gapless.topLeftCorner
        guard let delta = ((orientation == .h ? width : height) - children.sumOf { $0.getWeight(orientation) })
            .div(children.count) else { return }
        let lastIndex = children.indices.last
        for (i, child) in children.withIndex {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            let rawGap = config.gaps.inner.get(orientation).toDouble()
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0)
            child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width:  orientation == .h ? child.hWeight - gap : width,
                height: orientation == .v ? child.vWeight - gap : height,
                gapless: Rect(
                    topLeftX: gaplessPoint.x,
                    topLeftY: gaplessPoint.y,
                    width:  orientation == .h ? child.hWeight : width,
                    height: orientation == .v ? child.vWeight : height
                )
            )
            gaplessPoint = orientation == .h ? gaplessPoint.addingXOffset(child.hWeight) : gaplessPoint.addingYOffset(child.vWeight)
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, gapless: Rect) {
        guard let mruIndex: Int = mostRecentChild?.ownIndexOrNil else { return }
        for (index, child) in children.withIndex {
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
                    gapless: gapless
                )
            case .v:
                child.layoutRecursive(
                    point + CGPoint(x: 0, y: lPadding),
                    width: width,
                    height: height - lPadding - rPadding,
                    gapless: gapless
                )
            }
        }
    }
}
