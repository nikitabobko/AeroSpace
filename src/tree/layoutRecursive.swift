extension TreeNode {
    func layoutRecursive(_ point: CGPoint, focusedWindow: Window?, width: CGFloat, height: CGFloat) {
        var point = point
        // lastAppliedLayoutRect shouldn't be indented
        let rect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        if let orientation = (self as? TilingContainer)?.orientation, orientation == (parent as? TilingContainer)?.orientation {
            point = orientation == .h
                ? point + CGPoint(x: 0, y: config.indentForNestedContainersWithTheSameOrientation)
                : point + CGPoint(x: config.indentForNestedContainersWithTheSameOrientation, y: 0)
        }
        switch genericKind {
        case .workspace(let workspace):
            lastAppliedLayoutTilingRectForMouse = rect
            workspace.rootTilingContainer.layoutRecursive(point, focusedWindow: focusedWindow, width: width, height: height)
        case .window(let window):
            if window.windowId != currentlyManipulatedWithMouseWindowId {
                lastAppliedLayoutTilingRectForMouse = rect
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
            lastAppliedLayoutTilingRectForMouse = rect
            switch container.layout {
            case .list:
                container.layoutList(point, focusedWindow: focusedWindow, width: width, height: height)
            case .accordion:
                container.layoutAccordion(point, focusedWindow: focusedWindow, width: width, height: height)
            }
        }
    }
}

private extension TilingContainer {
    func layoutList(_ point: CGPoint, focusedWindow: Window?, width: CGFloat, height: CGFloat) {
        var point = point
        guard let delta = ((orientation == .h ? width : height) - children.sumOf { $0.getWeight(orientation) })
            .div(children.count) else { return }
        for child in children {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            child.layoutRecursive(
                point,
                focusedWindow: focusedWindow,
                width: orientation == .h ? child.hWeight : width,
                height: orientation == .v ? child.vWeight : height
            )
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    func layoutAccordion(_ point: CGPoint, focusedWindow: Window?, width: CGFloat, height: CGFloat) {
        guard let mruIndex: Int = mostRecentChildIndexForAccordion ?? mostRecentChild?.ownIndexOrNil else { return }
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
                    focusedWindow: focusedWindow,
                    width: width - rPadding - lPadding,
                    height: height
                )
            case .v:
                child.layoutRecursive(
                    point + CGPoint(x: 0, y: lPadding),
                    focusedWindow: focusedWindow,
                    width: width,
                    height: height - lPadding - rPadding
                )
            }
        }
    }
}
