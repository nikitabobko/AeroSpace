extension TreeNode {
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, startup: Bool) {
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
            lastAppliedLayoutRect = rect
            workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, startup: startup)
        case .window(let window):
            if window.windowId != currentlyManipulatedWithMouseWindowId {
                lastAppliedLayoutRect = rect
                window.setTopLeftCorner(point)
                window.setSize(CGSize(width: width, height: height))
                if startup { // It makes the layout more good-looking on the start. Good first impression
                    window.focus()
                }
            }
        case .tilingContainer(let container):
            lastAppliedLayoutRect = rect
            switch container.layout {
            case .list:
                container.layoutList(point, width: width, height: height, startup: startup)
            case .accordion:
                container.layoutAccordion(point, width: width, height: height, startup: startup)
            }
        }
    }
}

private extension TilingContainer {
    func layoutList(_ point: CGPoint, width: CGFloat, height: CGFloat, startup: Bool) {
        var point = point
        guard let delta = ((orientation == .h ? width : height) - children.sumOf { $0.getWeight(orientation) })
            .div(children.count) else { return }
        for child in children {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            child.layoutRecursive(
                point,
                width: orientation == .h ? child.hWeight : width,
                height: orientation == .v ? child.vWeight : height,
                startup: startup
            )
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, startup: Bool) {
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
                    width: width - rPadding - lPadding,
                    height: height,
                    startup: startup
                )
            case .v:
                child.layoutRecursive(
                    point + CGPoint(x: 0, y: lPadding),
                    width: width,
                    height: height - lPadding - rPadding,
                    startup: startup
                )
            }
        }
    }
}
