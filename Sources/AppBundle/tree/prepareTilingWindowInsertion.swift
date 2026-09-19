import Common

extension Workspace {
    // May create a container. The caller must bind the new window before normalization runs.
    @MainActor
    func prepareTilingWindowInsertion(autoTile: Bool) -> BindingData {
        // If a floating window is focused, auto tiling splits the most recent tile instead of adding one more sibling to the root
        let mruWindow = autoTile && config.enableAutoTiling
            ? (mostRecentWindowRecursive?.takeIf { $0.parent is TilingContainer } ?? rootTilingContainer.mostRecentWindowRecursive)
            : mostRecentWindowRecursive
        guard let window = mruWindow, let parent = window.parent as? TilingContainer else {
            return BindingData(parent: rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        if autoTile && config.enableAutoTiling && parent.layout == .tiles && parent.children.count >= 2 {
            let previousBinding = window.unbindFromParent()
            let split = TilingContainer(
                parent: parent,
                adaptiveWeight: previousBinding.adaptiveWeight,
                parent.orientation.opposite,
                .tiles,
                index: previousBinding.index,
            )
            window.bind(to: split, adaptiveWeight: 1, index: 0)
            return BindingData(parent: split, adaptiveWeight: 1, index: 1)
        }
        return BindingData(parent: parent, adaptiveWeight: WEIGHT_AUTO, index: window.ownIndex.orDie() + 1)
    }
}
