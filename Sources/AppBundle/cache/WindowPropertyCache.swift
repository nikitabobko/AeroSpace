import AppKit
import Common

@MainActor
final class WindowPropertyCache {
    private struct CachedProperties {
        let title: String?
        let role: String?
        let subrole: String?
        let timestamp: Date

        var isExpired: Bool {
            // Cache for 5 seconds for relatively stable properties
            timestamp.distance(to: .now) > 5.0
        }
    }

    private struct VolatileProperties {
        let size: CGSize?
        let position: CGPoint?
        let rect: Rect?
        let isFullscreen: Bool?
        let isMinimized: Bool?
        let timestamp: Date

        var isExpired: Bool {
            // Cache for only 0.5 seconds for volatile properties
            timestamp.distance(to: .now) > 0.5
        }
    }

    static let shared = WindowPropertyCache()

    private var stableCache: [UInt32: CachedProperties] = [:]
    private var volatileCache: [UInt32: VolatileProperties] = [:]

    private init() {}

    func getCachedTitle(_ windowId: UInt32) -> String? {
        guard let cached = stableCache[windowId], !cached.isExpired else { return nil }
        return cached.title
    }

    func getCachedRole(_ windowId: UInt32) -> String? {
        guard let cached = stableCache[windowId], !cached.isExpired else { return nil }
        return cached.role
    }

    func getCachedSubrole(_ windowId: UInt32) -> String? {
        guard let cached = stableCache[windowId], !cached.isExpired else { return nil }
        return cached.subrole
    }

    func getCachedSize(_ windowId: UInt32) -> CGSize? {
        guard let cached = volatileCache[windowId], !cached.isExpired else { return nil }
        return cached.size
    }

    func getCachedPosition(_ windowId: UInt32) -> CGPoint? {
        guard let cached = volatileCache[windowId], !cached.isExpired else { return nil }
        return cached.position
    }

    func getCachedRect(_ windowId: UInt32) -> Rect? {
        guard let cached = volatileCache[windowId], !cached.isExpired else { return nil }
        return cached.rect
    }

    func getCachedIsFullscreen(_ windowId: UInt32) -> Bool? {
        guard let cached = volatileCache[windowId], !cached.isExpired else { return nil }
        return cached.isFullscreen
    }

    func getCachedIsMinimized(_ windowId: UInt32) -> Bool? {
        guard let cached = volatileCache[windowId], !cached.isExpired else { return nil }
        return cached.isMinimized
    }

    func updateCache(windowId: UInt32, properties: AxBatchFetcher.WindowProperties) {
        let now = Date()

        // Update stable properties cache
        stableCache[windowId] = CachedProperties(
            title: properties.title,
            role: properties.role,
            subrole: properties.subrole,
            timestamp: now,
        )

        // Update volatile properties cache
        volatileCache[windowId] = VolatileProperties(
            size: properties.size,
            position: properties.position,
            rect: properties.rect,
            isFullscreen: properties.isFullscreen,
            isMinimized: properties.isMinimized,
            timestamp: now,
        )
    }

    func invalidate(windowId: UInt32) {
        stableCache.removeValue(forKey: windowId)
        volatileCache.removeValue(forKey: windowId)
    }

    func invalidateAll() {
        stableCache.removeAll()
        volatileCache.removeAll()
    }

    func invalidateVolatile(windowId: UInt32) {
        volatileCache.removeValue(forKey: windowId)
    }

    // Clean up expired entries periodically
    func cleanupExpiredEntries() {
        let now = Date()

        stableCache = stableCache.filter { _, cached in
            cached.timestamp.distance(to: now) <= 5.0
        }

        volatileCache = volatileCache.filter { _, cached in
            cached.timestamp.distance(to: now) <= 0.5
        }
    }
}
