import AppKit
import Common

extension Workspace {
    @MainActor func normalizeContainers() {
        let root = rootTilingContainer
        root.unbindEmptyAndFlattenContainersRecursive()
        // rootTilingContainer.deriveAxLifeStatusRecursive()
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            root.normalizeOppositeOrientationForNestedContainersRecursive(parentOrientation: nil)
        }
        if config.enableNormalizationMasterStack {
            root.normalizeMasterStack()
        }
    }
}

extension TilingContainer {
    /// Reshapes the workspace into a dwm-like master-stack layout:
    /// `masterCount` windows in the left column and all remaining windows
    /// stacked vertically in the right column.
    ///
    /// The pass is idempotent: it rebuilds the tree only when the current shape
    /// doesn't match the requested one. That way manual resizing (which changes
    /// adaptive weights) isn't reset on every refresh.
    @MainActor fileprivate func normalizeMasterStack() {
        guard isRootContainer, layout == .tiles, orientation == .h else { return }
        let windows = tilingWindowsInVisualOrder()
        let masterCount = min(max(config.masterStackMasterCount, 1), windows.count)
        let stackCount = windows.count - masterCount
        guard stackCount > 0 else { return } // One window or zero windows: nothing to arrange
        guard !hasMasterStackShape(masterCount: masterCount, stackCount: stackCount) else { return }
        rebuildMasterStack(windows: windows, masterCount: masterCount)
    }

    @MainActor private func tilingWindowsInVisualOrder() -> [Window] {
        var result: [Window] = []
        func visit(_ node: TreeNode) {
            switch node.tilingTreeNodeCasesOrDie() {
                case .window(let window): result.append(window)
                case .tilingContainer(let container): container.inhabitedChildren.forEach(visit)
            }
        }
        inhabitedChildren.forEach(visit)
        return result
    }

    @MainActor private func hasMasterStackShape(masterCount: Int, stackCount: Int) -> Bool {
        guard children.count == 2 else { return false }
        func isColumn(_ node: TreeNode, windowsCount: Int) -> Bool {
            if windowsCount == 1 {
                return node is Window
            }
            guard let container = node as? TilingContainer else { return false }
            return container.layout == .tiles && container.orientation == .v &&
                container.children.count == windowsCount &&
                container.children.allSatisfy { $0 is Window }
        }
        return isColumn(children[0], windowsCount: masterCount) &&
            isColumn(children[1], windowsCount: stackCount)
    }

    @MainActor private func rebuildMasterStack(windows: [Window], masterCount: Int) {
        let mostRecentWindow = mostRecentWindowRecursive
        let masterWidth = CGFloat(min(max(config.masterStackMasterWidthPercent, 10), 90)) / 100
        for window in windows {
            window.unbindFromParent()
        }
        for child in children { // Only empty containers are left at this point
            child.unbindFromParent()
        }
        bindMasterStackColumn(Array(windows.prefix(masterCount)), weight: masterWidth)
        bindMasterStackColumn(Array(windows.dropFirst(masterCount)), weight: 1 - masterWidth)
        // Preserve the MRU anchor: a newly opened window must be inserted next to
        // the window that was focused before the rebuild, not next to the last
        // window of the stack.
        mostRecentWindow?.markAsMostRecentChild()
    }

    @MainActor private func bindMasterStackColumn(_ windows: [Window], weight: CGFloat) {
        if let window = windows.singleOrNil() {
            window.bind(to: self, adaptiveWeight: weight, index: INDEX_BIND_LAST)
        } else {
            let column = TilingContainer.newVTiles(parent: self, adaptiveWeight: weight, index: INDEX_BIND_LAST)
            for window in windows {
                window.bind(to: column, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            }
        }
    }
}

extension TilingContainer {
    /// This function has probably way too many responsibilities:
    /// 1. It unbinds empty containers
    /// 2. It flattens containers that contain only a single child (excluding the root container)
    /// 3. It sets correct lifeStatus values
    ///
    /// todo: It's not clear what happens with mru in this function (does mru get rewritten by the recursive calls?).
    ///       Is it O(n^2) complexity?
    @MainActor fileprivate func unbindEmptyAndFlattenContainersRecursive() {
        if isRootContainer { // Special logic for root node to keep it always bound
            if let child = children.singleOrNil() as? TilingContainer, config.enableNormalizationFlattenContainers {
                child.unbindFromParent()
                for grandChild in child.children {
                    let data = grandChild.unbindFromParent()
                    grandChild.bind(to: self, adaptiveWeight: data.adaptiveWeight, index: INDEX_BIND_LAST)
                }
                self.copyFrom(child)
            }
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndFlattenContainersRecursive()
            }
            self.lifeStatus = .alive
        } else if let child = children.singleOrNil(), config.enableNormalizationFlattenContainers {
            child.unbindFromParent()
            let mru = parent?.mostRecentChild
            let previousBinding = unbindFromParent() // Kill the current node
            child.bind(to: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            (child as? TilingContainer)?.unbindEmptyAndFlattenContainersRecursive()
            if mru != self {
                mru?.markAsMostRecentChild()
            } else {
                child.markAsMostRecentChild()
            }
        } else {
            var inhabitedChildrenCount = 0
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndFlattenContainersRecursive()
                inhabitedChildrenCount += child.tilingTreeNodeCasesOrDie().isInhabited ? 1 : 0
            }
            if children.isEmpty {
                unbindFromParent()
            }
            if inhabitedChildrenCount == 1 && config.enableNormalizationFlattenContainers {
                lifeStatus = .mustBeFlattened
            } else {
                lifeStatus = inhabitedChildrenCount > 0 ? .alive : .deadOrInvisible
            }
        }
    }
}
