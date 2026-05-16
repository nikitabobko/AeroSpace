extension Workspace {
    @MainActor func normalizeContainers() {
        rootTilingContainer.unbindEmptyAndAutoFlatten() // Beware! rootTilingContainer may change after this line of code
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

extension TilingContainer {
    @MainActor fileprivate func unbindEmptyAndAutoFlatten() {
        // Treat windows that are temporarily detached (in macOS native fullscreen,
        // minimized, or hidden) as logical children of this container. Without
        // this, an accordion-of-two that has one child in fullscreen looks like a
        // single-child container and gets flattened -- which destroys the
        // container the fullscreen window expects to come back to.
        if let child = children.singleOrNil(), pendingFullscreenChildren == 0,
           config.enableNormalizationFlattenContainers && (child is TilingContainer || !isRootContainer)
        {
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
            if children.isEmpty && pendingFullscreenChildren == 0 && !isRootContainer {
                unbindFromParent()
            }
        }
    }
}
