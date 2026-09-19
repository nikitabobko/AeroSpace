import Common

extension Workspace {
    // May create a container. The caller must bind the new window before normalization runs.
    @MainActor
    func prepareTilingWindowInsertion(autoTile: Bool) -> BindingData {
        if autoTile, let split = prepareAutoTilingSplit() { return split }
        guard let window = mostRecentWindowRecursive, let parent = window.parent as? TilingContainer else {
            return BindingData(parent: rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        return BindingData(parent: parent, adaptiveWeight: WEIGHT_AUTO, index: window.ownIndex.orDie() + 1)
    }

    /// Split the most recent tile in the opposite direction to make room for one more window.
    /// `nil` if auto tiling is disabled, or if there is nothing to split (the window is going to be the first or
    /// the second window in the container).
    /// Creates a container. The caller must bind the window before normalization runs.
    @MainActor
    func prepareAutoTilingSplit() -> BindingData? {
        guard config.enableAutoTiling else { return nil }
        // The root might have inherited the orientation of a collapsed stack ([A | B/C] -> close A -> close C).
        // The second window must go next to the first one in the default orientation, the same as in a fresh workspace
        let root = rootTilingContainer
        if root.layout == .tiles && root.children.count == 1 && root.children.first is Window {
            root.changeOrientation(defaultRootContainerOrientation)
        }
        // If a floating window is focused, split the most recent tile instead of adding one more sibling to the root
        let mruTile = mostRecentWindowRecursive?.takeIf { $0.parent is TilingContainer } ?? rootTilingContainer.mostRecentWindowRecursive
        guard let window = mruTile, let parent = window.parent as? TilingContainer,
              parent.layout == .tiles && parent.children.count >= 2
        else { return nil }
        return window.prepareSplit(parent.orientation.opposite)
    }
}

extension Window {
    /// Make room for one more window next to this tile. The tile gives up half of its space, the other tiles aren't
    /// affected. `nil` if the window isn't a tile of a `tiles` container.
    /// Creates a container. The caller must bind the new window before normalization runs.
    @MainActor
    func prepareSplit(_ orientation: Orientation) -> BindingData? {
        guard let parent = parent as? TilingContainer, parent.layout == .tiles else { return nil }
        let previousBinding = unbindFromParent()
        let split = TilingContainer(
            parent: parent,
            adaptiveWeight: previousBinding.adaptiveWeight,
            orientation,
            .tiles,
            index: previousBinding.index,
        )
        bind(to: split, adaptiveWeight: 1, index: 0)
        return BindingData(parent: split, adaptiveWeight: 1, index: 1)
    }
}
