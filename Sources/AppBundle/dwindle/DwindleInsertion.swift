import AppKit
import Common

/// Hyprland-style binary-tree dwindle insertion.
///
/// When a new window is added to a workspace whose insertion target sits inside
/// a `Layout.dwindle` container, this algorithm:
///
///   1. Snapshots the target's parent slot and weight.
///   2. Unbinds the target from its parent.
///   3. Creates a new `Layout.dwindle` `TilingContainer` at the target's old slot,
///      inheriting the target's weight.
///   4. Binds the target into one side of the new container.
///   5. Returns `BindingData` pointing at the *other* side, where the caller
///      (`MacWindow.getOrRegister` or `Window.relayoutWindow`) binds the new window.
///
/// The result is a binary tree with alternating-orientation splits — visually the
/// same as Hyprland's dwindle layout. Rendering is delegated to `layoutTiles`
/// (see `layoutRecursive.swift`).
///
/// Returns `nil` when dwindle should NOT apply — either because there's no
/// resolved target (empty workspace), or the target's parent layout isn't
/// `.dwindle`. The caller falls back to standard sibling-insertion.
enum DwindleInsertion {
    /// Computes a `BindingData` that wraps the resolved target window and returns
    /// a slot for the new window.
    ///
    /// **Side effects**: Unbinds the target from its parent, creates a new
    /// `TilingContainer`, and binds the target into it. These mutations happen
    /// before returning. The current call-site contract for
    /// `unbindAndGetBindingDataForNewTilingWindow` already permits a side-effect
    /// unbind on the same path.
    @MainActor
    static func compute(workspace: Workspace) -> BindingData? {
        guard let target = resolveTarget(workspace: workspace) else { return nil }
        guard let parent = target.parent as? TilingContainer, parent.layout == .dwindle else {
            return nil
        }
        let dwindleCfg = config.dwindle

        let cursor = mouseLocation
        let rect = target.lastAppliedLayoutPhysicalRect
        let parentOrientation = parent.orientation

        let decision = decide(
            cursor: cursor,
            targetRect: rect,
            parentOrientation: parentOrientation,
            cfg: dwindleCfg,
        )

        // Snapshot the target's slot before mutating.
        let oldIndex = target.ownIndex.orDie()
        let oldWeight = target.getWeight(parentOrientation)

        // Compute the new window's weight share from `default-split-ratio` and
        // `split-width-multiplier`. Clamped to avoid degenerate panes that the
        // layout pass would have to redistribute on the very next render.
        let rawRatio = dwindleCfg.defaultSplitRatio * dwindleCfg.splitWidthMultiplier
        let ratio: CGFloat = rawRatio.clamped(to: 0.05 ... 0.95)
        // Pick a fixed scale (100). Children's relative ratios are what the
        // tiles layout pass cares about — absolute values get redistributed
        // anyway via the `delta` computation in `layoutTiles`.
        let totalScale: CGFloat = 100
        let newWindowWeight = ratio * totalScale
        let targetWeight = (1 - ratio) * totalScale

        // Wrap step: unbind target, create the new dwindle split container in
        // its old slot inheriting the old weight, and bind target into one side.
        target.unbindFromParent()
        let split = TilingContainer(
            parent: parent,
            adaptiveWeight: oldWeight,
            decision.orientation,
            .dwindle,
            index: oldIndex,
        )
        if dwindleCfg.preserveSplit {
            split.preserveSplit = true
        }

        // Bind target at index 0; the caller will insert the new window at
        // index `side` (0 or 1). When `side == 0`, the new window pushes target
        // to index 1; when `side == 1`, target stays at 0 and new window
        // appends. Either way, the final order matches `decision.side`.
        target.bind(to: split, adaptiveWeight: targetWeight, index: 0)

        return BindingData(parent: split, adaptiveWeight: newWindowWeight, index: decision.side)
    }

    /// Resolves the focused/cursor-targeted window for dwindle to split.
    ///
    /// - `[dwindle].use-active-for-splits = true` (default): the workspace's MRU window.
    /// - `[dwindle].use-active-for-splits = false`: the window under the cursor;
    ///    falls back to MRU if no window contains the cursor.
    @MainActor
    private static func resolveTarget(workspace: Workspace) -> Window? {
        if config.dwindle.useActiveForSplits {
            return workspace.mostRecentWindowRecursive
        }
        let cursor = mouseLocation
        if let underCursor = cursor.findIn(tree: workspace.rootTilingContainer, virtual: false) {
            return underCursor
        }
        return workspace.mostRecentWindowRecursive
    }

    /// Joint orientation/side decision. `smart-split` with cursor inside the
    /// target's rect overrides everything else; otherwise `force-split` and the
    /// target's aspect ratio decide.
    ///
    /// Internal (not private) so `DwindleInsertionTest` can drive this as a
    /// pure function with synthesised cursor / rect inputs without having to
    /// stub `NSEvent.mouseLocation`.
    @MainActor
    static func decide(
        cursor: CGPoint,
        targetRect: Rect?,
        parentOrientation: Orientation,
        cfg: DwindleConfig,
    ) -> (orientation: Orientation, side: Int) {
        // Smart-split path — cursor's closest edge inside the target rect picks
        // both orientation and side.
        if cfg.smartSplit, let rect = targetRect, rect.contains(cursor) {
            let distLeft = cursor.x - rect.minX
            let distRight = rect.maxX - cursor.x
            let distTop = cursor.y - rect.minY
            let distBottom = rect.maxY - cursor.y
            // Closest edge wins.
            let minDist = min(distLeft, distRight, distTop, distBottom)
            if minDist == distLeft {
                return (.h, 0)
            } else if minDist == distRight {
                return (.h, 1)
            } else if minDist == distTop {
                return (.v, 0)
            } else {
                return (.v, 1)
            }
        }

        // Aspect-ratio orientation: split along the longer axis. Falls back to
        // the *opposite* of the parent's orientation when the rect is missing
        // (e.g., target hasn't been laid out yet) so dwindle still alternates.
        let orientation: Orientation = if let rect = targetRect {
            rect.width >= rect.height ? .h : .v
        } else {
            parentOrientation.opposite
        }

        // Force-split decides the side.
        let side: Int = switch cfg.forceSplit {
            case .auto, .second: 1
            case .first: 0
        }
        return (orientation, side)
    }
}

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
