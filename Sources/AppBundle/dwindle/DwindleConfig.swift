import AppKit
import Common

/// User-configurable knobs for the `Layout.dwindle` insertion algorithm.
///
/// Mirrors Hyprland's `dwindle:*` plugin options where they map cleanly to
/// AeroSpace's tree model. See `Sources/AppBundle/dwindle/DwindleInsertion.swift`
/// for the algorithm that consumes these.
///
/// Only the dwindle insertion path reads these fields. A workspace whose root
/// container is `tiles` or `accordion` is unaffected.
struct DwindleConfig: ConvenienceCopyable, Equatable, Sendable {
    /// Which side of the focused window the new window joins.
    /// `.auto` matches Hyprland's default (right/bottom).
    var forceSplit: ForceSplit = .auto
    /// When `true`, cursor position inside the focused window decides split
    /// orientation and side, overriding `forceSplit`.
    var smartSplit: Bool = false
    /// When `true`, dwindle-created split containers survive when reduced to
    /// a single child (instead of being collapsed by `unbindEmptyAndAutoFlatten`).
    /// Only set on containers created by the dwindle insertion algorithm —
    /// other containers are unaffected.
    var preserveSplit: Bool = false
    /// Initial weight ratio between the focused window and the new window.
    /// Must be in the open interval `(0.0, 1.0)`.
    var defaultSplitRatio: CGFloat = 0.5
    /// Multiplier applied on top of `defaultSplitRatio` to compute the new
    /// window's weight. Must be > 0.
    var splitWidthMultiplier: CGFloat = 1.0
    /// When `true`, drop outer gaps if the workspace contains exactly one window.
    /// Scoped to workspaces whose root layout is `.dwindle`.
    var noGapsWhenOnly: Bool = false
    /// When `true` (default), splits target the focused (most-recent) window.
    /// When `false`, splits target the window under the cursor (falling back to
    /// MRU when cursor is over no window).
    var useActiveForSplits: Bool = true
}

/// Hyprland `force_split` enum, but with named cases instead of magic numbers.
enum ForceSplit: String, Equatable, Sendable {
    /// Hyprland's default: new window goes to index 1 (right/bottom).
    case auto
    /// New window goes to index 0 (left/top).
    case first
    /// New window goes to index 1 (right/bottom). Equivalent to `auto`,
    /// kept distinct for parity with Hyprland's enum.
    case second
}
