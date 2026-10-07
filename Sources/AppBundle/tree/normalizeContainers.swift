import Common

extension TreeNode {
    /// Returns the node's workspace override if set, otherwise the global config flag.
    /// A detached node belongs to no workspace, so it resolves to the global config.
    @MainActor func isNormalizationEnabled(_ kind: NormalizationKind) -> Bool {
        nodeWorkspace?.normalizationOverride[kind] ?? config.isNormalizationEnabledGlobally(kind)
    }
}

extension Config {
    fileprivate func isNormalizationEnabledGlobally(_ kind: NormalizationKind) -> Bool {
        switch kind {
            case .flattenContainers: enableNormalizationFlattenContainers
            case .oppositeOrientationForNestedContainers: enableNormalizationOppositeOrientationForNestedContainers
        }
    }
}

extension Workspace {
    @MainActor func normalizeContainers() {
        // Always called: the function also removes effectively-empty containers
        // regardless of the flatten flag.
        // Beware! rootTilingContainer may change after this line of code
        rootTilingContainer.unbindEmptyAndAutoFlatten(allowFlatten: isNormalizationEnabled(.flattenContainers))
        if isNormalizationEnabled(.oppositeOrientationForNestedContainers) {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

extension TilingContainer {
    @MainActor fileprivate func unbindEmptyAndAutoFlatten(allowFlatten: Bool) {
        if let child = children.singleOrNil(), allowFlatten && (child is TilingContainer || !isRootContainer) {
            child.unbindFromParent()
            let mru = parent?.mostRecentChild
            let previousBinding = unbindFromParent()
            child.bind(to: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            (child as? TilingContainer)?.unbindEmptyAndAutoFlatten(allowFlatten: allowFlatten)
            if mru != self {
                mru?.markAsMostRecentChild()
            } else {
                child.markAsMostRecentChild()
            }
        } else {
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndAutoFlatten(allowFlatten: allowFlatten)
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }
}
