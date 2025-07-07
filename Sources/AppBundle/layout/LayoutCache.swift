import AppKit
import Common

/// Actor that manages caching of layout calculation results
actor LayoutCache {
    private var cache: [String: CachedLayout] = [:]
    private let maxCacheSize: Int = 100
    private let cacheTimeout: TimeInterval = 30.0 // 30 seconds
    
    private struct CachedLayout {
        let result: BackgroundLayoutCalculator.LayoutResult
        let timestamp: Date
        let accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 30.0
        }
        
        func withIncrementedAccess() -> CachedLayout {
            CachedLayout(
                result: result,
                timestamp: timestamp,
                accessCount: accessCount + 1
            )
        }
    }
    
    /// Get cached layout result if available and valid
    func getCachedLayout(for layoutId: String) -> BackgroundLayoutCalculator.LayoutResult? {
        guard let cached = cache[layoutId], !cached.isExpired else {
            // Clean up expired entry
            cache.removeValue(forKey: layoutId)
            return nil
        }
        
        // Update access count for LRU eviction
        cache[layoutId] = cached.withIncrementedAccess()
        return cached.result
    }
    
    /// Cache a layout result
    func cacheLayout(_ result: BackgroundLayoutCalculator.LayoutResult) {
        // Ensure we don't exceed cache size
        if cache.count >= maxCacheSize {
            evictLeastRecentlyUsed()
        }
        
        cache[result.layoutId] = CachedLayout(
            result: result,
            timestamp: Date(),
            accessCount: 1
        )
    }
    
    /// Invalidate cached layouts for a specific workspace
    func invalidate(workspaceName: String) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(workspaceName) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    /// Invalidate all cached layouts
    func invalidateAll() {
        cache.removeAll()
    }
    
    /// Clean up expired cache entries
    func cleanupExpired() {
        let expiredKeys = cache.compactMap { key, cached in
            cached.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
    }
    
    /// Get cache statistics for monitoring
    func getStatistics() -> CacheStatistics {
        let totalEntries = cache.count
        let expiredEntries = cache.values.filter { $0.isExpired }.count
        let totalMemoryEstimate = cache.values.reduce(0) { total, cached in
            total + estimateMemoryUsage(for: cached.result)
        }
        
        return CacheStatistics(
            totalEntries: totalEntries,
            expiredEntries: expiredEntries,
            estimatedMemoryUsage: totalMemoryEstimate,
            hitRate: calculateHitRate()
        )
    }
    
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    private func calculateHitRate() -> Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
    
    private func evictLeastRecentlyUsed() {
        // Find the entry with the lowest access count
        guard let lruKey = cache.min(by: { $0.value.accessCount < $1.value.accessCount })?.key else {
            return
        }
        
        cache.removeValue(forKey: lruKey)
    }
    
    private func estimateMemoryUsage(for result: BackgroundLayoutCalculator.LayoutResult) -> Int {
        // Rough estimate: 200 bytes per layout calculation + base overhead
        return 1000 + (result.calculations.count * 200)
    }
}

/// Statistics about cache performance
struct CacheStatistics: Sendable {
    let totalEntries: Int
    let expiredEntries: Int
    let estimatedMemoryUsage: Int
    let hitRate: Double
    
    var memoryUsageInMB: Double {
        Double(estimatedMemoryUsage) / 1024.0 / 1024.0
    }
    
    var healthScore: Double {
        // Health score based on hit rate and memory efficiency
        let hitRateScore = hitRate
        let memoryScore = max(0, 1.0 - (memoryUsageInMB / 50.0)) // Penalty if using > 50MB
        let expiredScore = totalEntries > 0 ? 1.0 - (Double(expiredEntries) / Double(totalEntries)) : 1.0
        
        return (hitRateScore + memoryScore + expiredScore) / 3.0
    }
}

/// Background task to periodically clean up the cache
@MainActor
class LayoutCacheManager {
    static let shared = LayoutCacheManager()
    private var cleanupTask: Task<Void, Never>?
    
    private init() {
        startPeriodicCleanup()
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    private func startPeriodicCleanup() {
        cleanupTask = Task {
            while !Task.isCancelled {
                // Clean up every 5 minutes
                try? await Task.sleep(for: .seconds(300))
                
                await BackgroundLayoutCalculator.shared.cache.cleanupExpired()
            }
        }
    }
    
    /// Get current cache statistics
    func getStatistics() async -> CacheStatistics {
        await BackgroundLayoutCalculator.shared.cache.getStatistics()
    }
    
    /// Force cleanup of expired entries
    func forceCleanup() async {
        await BackgroundLayoutCalculator.shared.cache.cleanupExpired()
    }
    
    /// Clear all cached layouts (useful for testing)
    func clearAll() async {
        await BackgroundLayoutCalculator.shared.cache.invalidateAll()
    }
}