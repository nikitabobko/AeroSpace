extension Workspace {
    @MainActor func normalizeContainers() {
        rootTilingContainer.unbindEmptyAndAutoFlatten() // Beware! rootTilingContainer may change after this line of code
        if config.enableNormalizationBinaryTree {
            rootTilingContainer.normalizeBinaryTree(rect: workspaceMonitor.visibleRectPaddedByOuterGaps)
        } else if config.enableNormalizationOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

extension TilingContainer {
    @MainActor fileprivate func unbindEmptyAndAutoFlatten() {
        if let child = children.singleOrNil(), config.enableNormalizationFlattenContainers && (child is TilingContainer || !isRootContainer) {
            child.unbindFromParent()
            let mru = parent?.mostRecentChild
            let previousBinding = unbindFromParent()
            child.bind(to: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
            if mru != self {
                mru?.markAsMostRecentChild()
            } else {
                child.markAsMostRecentChild()
            }
        } else {
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }

    @MainActor func normalizeBinaryTree(rect: Rect) {
        forceBinaryTree()
        setOrientation(rect.width > rect.height ? .h : .v)
        switch children.count {
            case 0: return
            case 1:
                (children[0] as? TilingContainer)?.normalizeBinaryTree(rect: rect)
            default: // 2 — guaranteed by forceBinaryTree
                let rects = rect.sliced(along: orientation, weights: children.map { $0.getWeight(orientation) })
                (children[0] as? TilingContainer)?.normalizeBinaryTree(rect: rects[0])
                (children[1] as? TilingContainer)?.normalizeBinaryTree(rect: rects[1])
        }
    }

    @MainActor private func forceBinaryTree() {
        if children.count <= 2 { return }
        let toWrap = Array(children.dropFirst())
        let wrapper = TilingContainer.newHTiles(parent: self, adaptiveWeight: WEIGHT_AUTO, index: 1)
        for child in toWrap {
            child.unbindFromParent()
            child.bind(to: wrapper, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
    }
}
