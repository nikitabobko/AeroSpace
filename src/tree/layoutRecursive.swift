extension TreeNode {
    func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, firstStart: Bool) {
        let rect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch kind {
        case .workspace(let workspace):
            lastAppliedLayoutRect = rect
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
            lastAppliedLayoutRect = rect
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
        guard let delta = ((orientation == .H ? width : height) - children.sumOf { $0.getWeight(orientation) })
            .div(children.count) else { return }
        var childPoint = point
        for child in children {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            child.layoutRecursive(
                childPoint,
                width: orientation == .H ? child.hWeight : width,
                height: orientation == .V ? child.vWeight : height,
                firstStart: firstStart
            )
            childPoint = orientation == .H
                ? childPoint.copy(\.x, childPoint.x + child.hWeight)
                : childPoint.copy(\.y, childPoint.y + child.vWeight)
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
