extension TreeNode {
    /// Containers' weights must be normalized before calling this function
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, firstStart: Bool) {
        let rect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch kind {
        case .workspace(let workspace):
            workspace.lastAppliedLayoutRect = rect
            workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, firstStart: firstStart)
        case .window(let window):
            if window.windowId != currentlyResizedWithMouseWindowId {
                lastAppliedLayoutRect = rect
                window.setTopLeftCorner(point)
                window.setSize(CGSize(width: width, height: height))
                if firstStart { // It makes the layout more good-looking on the start. Good first impression
                    window.focus()
                }
            }
        case .tilingContainer(let container):
            container.lastAppliedLayoutRect = rect
            switch container.layout {
            case .List:
                container.layoutList(point, width: width, height: height, firstStart: firstStart)
            case .Accordion:
                container.layoutAccordion(point, width: width, height: height, firstStart: firstStart)
            }
        }
    }
}

private extension TilingContainer {
    func layoutList(_ point: CGPoint, width: CGFloat, height: CGFloat, firstStart: Bool) {
        var childPoint = point
        for child in children {
            child.layoutRecursive(childPoint, width: child.hWeight, height: child.vWeight, firstStart: firstStart)
            switch orientation {
            case .H:
                childPoint = childPoint.copy(\.x, childPoint.x + child.hWeight)
            case .V:
                childPoint = childPoint.copy(\.y, childPoint.y + child.vWeight)
            }
        }
    }

    func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, firstStart: Bool) {
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
            case .H:
                child.layoutRecursive(
                    point + CGPoint(x: lPadding, y: 0),
                    width: width - rPadding - lPadding,
                    height: height,
                    firstStart: firstStart
                )
            case .V:
                child.layoutRecursive(
                    point + CGPoint(x: 0, y: lPadding),
                    width: width,
                    height: height - lPadding - rPadding,
                    firstStart: firstStart
                )
            }
        }
    }
}
