import AppKit
import Common

/// Advanced memoization system for layout calculations based on container fingerprints
@MainActor
class LayoutMemoizer {
    static let shared = LayoutMemoizer()
    
    private var memoCache: [LayoutFingerprint: MemoizedLayout] = [:]
    private let maxCacheSize: Int
    private let cacheTimeout: TimeInterval
    
    private struct MemoizedLayout {
        let fingerprint: LayoutFingerprint
        let result: LayoutResult
        let timestamp: Date
        let accessCount: Int
        let computationTime: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 30.0
        }
        
        func withIncrementedAccess() -> MemoizedLayout {
            MemoizedLayout(
                fingerprint: fingerprint,
                result: result,
                timestamp: timestamp,
                accessCount: accessCount + 1,
                computationTime: computationTime
            )
        }
    }
    
    struct LayoutResult: Sendable {
        let positions: [String: CGRect] // windowId -> position
        let containerSizes: [String: CGSize] // containerId -> size
        let computationMetadata: ComputationMetadata
        
        struct ComputationMetadata: Sendable {
            let nodeCount: Int
            let maxDepth: Int
            let complexityScore: Double
            let optimizationFlags: Set<String>
        }
    }
    
    private init() {
        self.maxCacheSize = config.performanceConfig.layoutCacheSize
        self.cacheTimeout = config.performanceConfig.layoutCacheTimeout
    }
    
    /// Check if we have a memoized result for the given workspace state
    func getMemoizedLayout(for fingerprint: LayoutFingerprint) -> LayoutResult? {
        guard config.performanceConfig.useLayoutMemoization else { return nil }
        
        guard let memoized = memoCache[fingerprint], !memoized.isExpired else {
            // Clean up expired entry
            memoCache.removeValue(forKey: fingerprint)
            return nil
        }
        
        // Update access count for LRU eviction
        memoCache[fingerprint] = memoized.withIncrementedAccess()
        
        if config.performanceConfig.monitoringConfig.enableDebugLogging {
            print("LayoutMemoizer: Cache hit for fingerprint \(fingerprint.hashValue)")
        }
        
        return memoized.result
    }
    
    /// Store a computed layout result
    func memoizeLayout(
        fingerprint: LayoutFingerprint,
        result: LayoutResult,
        computationTime: TimeInterval
    ) {
        guard config.performanceConfig.useLayoutMemoization else { return }
        
        // Ensure we don't exceed cache size
        if memoCache.count >= maxCacheSize {
            evictLeastValuable()
        }
        
        let memoized = MemoizedLayout(
            fingerprint: fingerprint,
            result: result,
            timestamp: Date(),
            accessCount: 1,
            computationTime: computationTime
        )
        
        memoCache[fingerprint] = memoized
        
        if config.performanceConfig.monitoringConfig.enableDebugLogging {
            print("LayoutMemoizer: Cached layout for fingerprint \(fingerprint.hashValue), computation time: \(computationTime)ms")
        }
    }
    
    /// Compute or retrieve memoized layout for a workspace
    func computeLayout(for workspace: Workspace, rect: Rect) async throws -> LayoutResult {
        let fingerprint = LayoutFingerprint(workspace: workspace, targetRect: rect)
        
        // Check for memoized result first
        if let memoized = getMemoizedLayout(for: fingerprint) {
            return memoized
        }
        
        // Compute new layout
        let startTime = Date()
        let result = try await performLayoutComputation(workspace: workspace, rect: rect)
        let computationTime = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
        
        // Memoize the result
        memoizeLayout(fingerprint: fingerprint, result: result, computationTime: computationTime)
        
        return result
    }
    
    /// Invalidate memoized layouts when workspace structure changes
    func invalidateLayouts(for workspace: Workspace) {
        let workspaceName = workspace.name
        let keysToRemove = memoCache.keys.filter { $0.workspaceName == workspaceName }
        
        for key in keysToRemove {
            memoCache.removeValue(forKey: key)
        }
        
        if config.performanceConfig.monitoringConfig.enableDebugLogging {
            print("LayoutMemoizer: Invalidated \(keysToRemove.count) cached layouts for workspace \(workspaceName)")
        }
    }
    
    /// Invalidate layouts when a specific window changes
    func invalidateLayouts(affectedBy windowId: CGWindowID) {
        let keysToRemove = memoCache.keys.filter { fingerprint in
            fingerprint.windowIds.contains(String(windowId))
        }
        
        for key in keysToRemove {
            memoCache.removeValue(forKey: key)
        }
        
        if config.performanceConfig.monitoringConfig.enableDebugLogging {
            print("LayoutMemoizer: Invalidated \(keysToRemove.count) cached layouts affected by window \(windowId)")
        }
    }
    
    /// Get cache statistics
    func getStatistics() -> MemoizationStatistics {
        let totalEntries = memoCache.count
        let expiredEntries = memoCache.values.filter { $0.isExpired }.count
        let totalComputationTime = memoCache.values.reduce(0) { $0 + $1.computationTime }
        let avgComputationTime = totalEntries > 0 ? totalComputationTime / Double(totalEntries) : 0
        
        let memoryUsage = memoCache.values.reduce(0) { total, memoized in
            total + estimateMemoryUsage(for: memoized.result)
        }
        
        return MemoizationStatistics(
            totalEntries: totalEntries,
            expiredEntries: expiredEntries,
            averageComputationTime: avgComputationTime,
            memoryUsage: memoryUsage,
            hitRate: calculateHitRate()
        )
    }
    
    /// Clean up expired entries
    func cleanupExpired() {
        let expiredKeys = memoCache.compactMap { key, memoized in
            memoized.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            memoCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty && config.performanceConfig.monitoringConfig.enableDebugLogging {
            print("LayoutMemoizer: Cleaned up \(expiredKeys.count) expired entries")
        }
    }
    
    // MARK: - Private Methods
    
    private var hitCount = 0
    private var missCount = 0
    
    private func calculateHitRate() -> Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
    
    private func evictLeastValuable() {
        // Eviction strategy: combination of LRU and computation cost
        guard let leastValuable = memoCache.min(by: { lhs, rhs in
            let lhsValue = Double(lhs.value.accessCount) / lhs.value.computationTime
            let rhsValue = Double(rhs.value.accessCount) / rhs.value.computationTime
            return lhsValue < rhsValue
        }) else { return }
        
        memoCache.removeValue(forKey: leastValuable.key)
    }
    
    private func estimateMemoryUsage(for result: LayoutResult) -> Int {
        // Rough estimate: 100 bytes per position + 50 bytes per container + overhead
        return 500 + (result.positions.count * 100) + (result.containerSizes.count * 50)
    }
    
    private func performLayoutComputation(workspace: Workspace, rect: Rect) async throws -> LayoutResult {
        // This would integrate with the existing layout system
        // For now, this is a simplified implementation
        
        var positions: [String: CGRect] = [:]
        var containerSizes: [String: CGSize] = [:]
        var nodeCount = 0
        var maxDepth = 0
        
        // Traverse the workspace and compute positions
        try await computeNodeLayout(
            node: workspace.rootTilingContainer,
            rect: rect,
            positions: &positions,
            containerSizes: &containerSizes,
            nodeCount: &nodeCount,
            currentDepth: 0,
            maxDepth: &maxDepth
        )
        
        let metadata = LayoutResult.ComputationMetadata(
            nodeCount: nodeCount,
            maxDepth: maxDepth,
            complexityScore: calculateComplexityScore(nodeCount: nodeCount, maxDepth: maxDepth),
            optimizationFlags: getOptimizationFlags()
        )
        
        return LayoutResult(
            positions: positions,
            containerSizes: containerSizes,
            computationMetadata: metadata
        )
    }
    
    private func computeNodeLayout(
        node: TreeNode,
        rect: Rect,
        positions: inout [String: CGRect],
        containerSizes: inout [String: CGSize],
        nodeCount: inout Int,
        currentDepth: Int,
        maxDepth: inout Int
    ) async throws {
        nodeCount += 1
        maxDepth = max(maxDepth, currentDepth)
        
        switch node.nodeCases {
        case .window(let window):
            positions[String(window.windowId)] = CGRect(
                x: rect.topLeftX,
                y: rect.topLeftY,
                width: rect.width,
                height: rect.height
            )
            
        case .tilingContainer(let container):
            containerSizes["\(container.orientation)_\(nodeCount)"] = CGSize(
                width: rect.width,
                height: rect.height
            )
            
            // Simplified layout for children
            let childRect = Rect(
                topLeftX: rect.topLeftX,
                topLeftY: rect.topLeftY,
                width: rect.width / CGFloat(max(1, container.children.count)),
                height: rect.height
            )
            
            for (index, child) in container.children.enumerated() {
                let offset = CGFloat(index) * childRect.width
                let adjustedRect = Rect(
                    topLeftX: rect.topLeftX + offset,
                    topLeftY: rect.topLeftY,
                    width: childRect.width,
                    height: childRect.height
                )
                
                try await computeNodeLayout(
                    node: child,
                    rect: adjustedRect,
                    positions: &positions,
                    containerSizes: &containerSizes,
                    nodeCount: &nodeCount,
                    currentDepth: currentDepth + 1,
                    maxDepth: &maxDepth
                )
            }
            
        default:
            break // Skip other node types
        }
    }
    
    private func calculateComplexityScore(nodeCount: Int, maxDepth: Int) -> Double {
        // Complexity score based on node count and depth
        return Double(nodeCount) * (1.0 + Double(maxDepth) * 0.5)
    }
    
    private func getOptimizationFlags() -> Set<String> {
        var flags: Set<String> = []
        
        if config.performanceConfig.useBackgroundLayoutCalculation {
            flags.insert("background_calculation")
        }
        
        if config.performanceConfig.useAdaptiveDebouncing {
            flags.insert("adaptive_debouncing")
        }
        
        return flags
    }
}

/// Statistics about memoization performance
struct MemoizationStatistics: Sendable {
    let totalEntries: Int
    let expiredEntries: Int
    let averageComputationTime: Double
    let memoryUsage: Int
    let hitRate: Double
    
    var memoryUsageInMB: Double {
        Double(memoryUsage) / 1024.0 / 1024.0
    }
    
    var efficiencyScore: Double {
        // Score based on hit rate and average computation savings
        let hitRateScore = hitRate
        let computationScore = min(1.0, averageComputationTime / 100.0) // Normalize to 100ms baseline
        return (hitRateScore + computationScore) / 2.0
    }
}