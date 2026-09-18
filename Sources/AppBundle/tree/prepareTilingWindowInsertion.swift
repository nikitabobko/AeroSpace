import Common

extension Workspace {
    @MainActor
    func prepareTilingWindowInsertion() -> BindingData {
        guard let window = mostRecentWindowRecursive, let parent = window.parent as? TilingContainer else {
            return BindingData(parent: rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        return BindingData(parent: parent, adaptiveWeight: WEIGHT_AUTO, index: window.ownIndex.orDie() + 1)
    }
}
