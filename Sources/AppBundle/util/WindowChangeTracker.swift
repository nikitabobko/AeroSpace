import AppKit
import Common

@MainActor
final class WindowChangeTracker {
    enum ChangeType {
        case created
        case destroyed
        case moved
        case resized
        case titleChanged
        case fullscreenChanged
        case minimizedChanged
    }
    
    struct WindowChange {
        let windowId: UInt32
        let changeType: ChangeType
        let timestamp: Date
    }
    
    static let shared = WindowChangeTracker()
    
    private var pendingChanges: [UInt32: Set<ChangeType>] = [:]
    private var lastProcessedTime = Date.distantPast
    
    private init() {}
    
    func trackChange(windowId: UInt32, changeType: ChangeType) {
        var changes = pendingChanges[windowId] ?? []
        changes.insert(changeType)
        pendingChanges[windowId] = changes
    }
    
    func trackCreated(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .created)
    }
    
    func trackDestroyed(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .destroyed)
        // Also invalidate cache for destroyed windows
        WindowPropertyCache.shared.invalidate(windowId: windowId)
        // Invalidate layout memoization cache
        LayoutMemoizer.shared.invalidateLayouts(affectedBy: CGWindowID(windowId))
    }
    
    func trackMoved(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .moved)
        WindowPropertyCache.shared.invalidateVolatile(windowId: windowId)
        // Layout changes when windows move
        LayoutMemoizer.shared.invalidateLayouts(affectedBy: CGWindowID(windowId))
    }
    
    func trackResized(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .resized)
        WindowPropertyCache.shared.invalidateVolatile(windowId: windowId)
    }
    
    func trackTitleChanged(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .titleChanged)
        WindowPropertyCache.shared.invalidate(windowId: windowId)
    }
    
    func trackFullscreenChanged(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .fullscreenChanged)
        WindowPropertyCache.shared.invalidateVolatile(windowId: windowId)
    }
    
    func trackMinimizedChanged(windowId: UInt32) {
        trackChange(windowId: windowId, changeType: .minimizedChanged)
        WindowPropertyCache.shared.invalidateVolatile(windowId: windowId)
    }
    
    func getPendingChanges() -> [UInt32: Set<ChangeType>] {
        let changes = pendingChanges
        pendingChanges = [:]
        lastProcessedTime = Date()
        return changes
    }
    
    func hasPendingChanges() -> Bool {
        !pendingChanges.isEmpty
    }
    
    func clearPendingChanges() {
        pendingChanges = [:]
    }
    
    // Check if a specific window has pending changes
    func hasPendingChanges(for windowId: UInt32) -> Bool {
        pendingChanges[windowId] != nil
    }
    
    // Get changes for a specific window
    func getChanges(for windowId: UInt32) -> Set<ChangeType>? {
        pendingChanges.removeValue(forKey: windowId)
    }
}