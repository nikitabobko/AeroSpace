extension Workspace {
    func normalizeContainers() {
        rootTilingContainer.unbindEmptyAndAutoFlatten() // Beware! rootTilingContainer may change after this line of code
        if config.autoOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

private extension TilingContainer {
    func unbindEmptyAndAutoFlatten() {
        if let child = children.singleOrNil(), config.autoFlattenContainers && (child is TilingContainer || !isRootContainer) {
            child.unbindFromParent()
            let previousBinding = unbindFromParent()
            child.bindTo(parent: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
        } else {
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndAutoFlatten()
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }

    func normalizeOppositeOrientationForNestedContainers() {
        if orientation == (parent as? TilingContainer)?.orientation {
            orientation = orientation.opposite
        }
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainers()
        }
    }
}
