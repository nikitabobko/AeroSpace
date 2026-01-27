extension Workspace {
    @MainActor func normalizeContainers() {
        rootTilingContainer.unbindEmptyAndAutoFlatten() // Beware! rootTilingContainer may change after this line of code
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
    }

    @MainActor func getDfsSignature() -> String {
        return rootTilingContainer.getDfsSignatureRecursive()
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

    @MainActor fileprivate func getDfsSignatureRecursive() -> String {
        let childrenSig = children.map { child in
            if let window = child as? Window {
                return "W:\(window.windowId)"
            } else if let container = child as? TilingContainer {
                return container.getDfsSignatureRecursive()
            } else {
                return "?"
            }
        }.joined(separator: ",")
        let orientation = orientation == .h ? "h" : "v"
        return "C[\(orientation)](\(childrenSig))"
    }
}
