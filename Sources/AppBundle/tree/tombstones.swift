/// CRDT inspired tombstone-like status
///
/// The only difference between 'dead' and invisible is their cleanup policy:
/// 1. invisible is never cleaned up
/// 2. dead is cleanuped up when we can guarantee that the screen is not locked
enum WindowLifeStatus {
    case dead // Closed windows OR Locked screen
    case invisible // Invisible macOS Spaces AND Background tabs
    case alive

    var isInhabited: Bool {
        switch self {
            case .alive: true

            case .dead: false
            case .invisible: false
        }
    }
}

/// TilingContainer tombstones
enum TilingContainerLifeStatus {
    /// Tombstone derived from WindowLifeStatus
    case deadOrInvisible
    /// must be flattened by normalization, but cannot since it contains half-dead children
    /// These types of containers must be transparent for ascensions and descensions
    /// These containers contain only a single alive child
    case mustBeFlattened
    case alive

    /// isInhabited is a building metaphore - mustBeFlattened contains a *single* stubborn tenant (child) that refuses to leave
    var isInhabited: Bool {
        switch self {
            case .mustBeFlattened: true
            case .alive: true

            case .deadOrInvisible: false
        }
    }
}
