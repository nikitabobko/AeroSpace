import AppKit
import Common

/// Unique fingerprint for workspace layout state used for memoization
struct LayoutFingerprint: Hashable, Sendable {
    let workspaceName: String
    let targetRect: HashableRect
    let containerStructure: ContainerStructureHash
    var windowIds: Set<String>
    let configurationHash: String
    let monitorId: String
    
    /// Hashable version of Rect for fingerprinting
    struct HashableRect: Hashable, Sendable {
        let topLeftX: CGFloat
        let topLeftY: CGFloat
        let width: CGFloat
        let height: CGFloat
        
        init(from rect: Rect) {
            self.topLeftX = rect.topLeftX
            self.topLeftY = rect.topLeftY
            self.width = rect.width
            self.height = rect.height
        }
    }
    
    /// Hash representing the hierarchical structure of containers
    struct ContainerStructureHash: Hashable, Sendable {
        let hash: String
        let nodeCount: Int
        let maxDepth: Int
        let layoutTypes: [String]
        
        @MainActor
        init(from container: TilingContainer) {
            var hasher = SHA256Hasher()
            var nodeCount = 0
            var maxDepth = 0
            var layoutTypes: [String] = []
            
            Self.hashContainerRecursive(
                container,
                hasher: &hasher,
                nodeCount: &nodeCount,
                currentDepth: 0,
                maxDepth: &maxDepth,
                layoutTypes: &layoutTypes
            )
            
            self.hash = hasher.finalize()
            self.nodeCount = nodeCount
            self.maxDepth = maxDepth
            self.layoutTypes = layoutTypes
        }
        
        @MainActor
        private static func hashContainerRecursive(
            _ node: TreeNode,
            hasher: inout SHA256Hasher,
            nodeCount: inout Int,
            currentDepth: Int,
            maxDepth: inout Int,
            layoutTypes: inout [String]
        ) {
            nodeCount += 1
            maxDepth = max(maxDepth, currentDepth)
            
            switch node.nodeCases {
            case .tilingContainer(let container):
                hasher.update(with: "container")
                hasher.update(with: container.orientation == .h ? "h" : "v")
                hasher.update(with: container.layout.rawValue)
                hasher.update(with: String(container.children.count))
                
                layoutTypes.append("\(container.orientation == .h ? "h" : "v")_\(container.layout.rawValue)")
                
                // Hash child structure
                for child in container.children {
                    hashContainerRecursive(
                        child,
                        hasher: &hasher,
                        nodeCount: &nodeCount,
                        currentDepth: currentDepth + 1,
                        maxDepth: &maxDepth,
                        layoutTypes: &layoutTypes
                    )
                }
                
            case .window(let window):
                hasher.update(with: "window")
                hasher.update(with: String(window.windowId))
                
            case .workspace:
                hasher.update(with: "workspace")
                for child in node.children {
                    hashContainerRecursive(
                        child,
                        hasher: &hasher,
                        nodeCount: &nodeCount,
                        currentDepth: currentDepth + 1,
                        maxDepth: &maxDepth,
                        layoutTypes: &layoutTypes
                    )
                }
                
            default:
                hasher.update(with: "other")
            }
        }
    }
    
    @MainActor
    init(workspace: Workspace, targetRect: Rect) {
        self.workspaceName = workspace.name
        self.targetRect = HashableRect(from: targetRect)
        self.containerStructure = ContainerStructureHash(from: workspace.rootTilingContainer)
        self.monitorId = workspace.workspaceMonitor.name
        
        // Collect window IDs
        var windowIds: Set<String> = []
        Self.collectWindowIds(from: workspace, windowIds: &windowIds)
        self.windowIds = windowIds
        
        // Hash relevant configuration
        self.configurationHash = Self.computeConfigurationHash()
    }
    
    @MainActor
    private static func collectWindowIds(from node: TreeNode, windowIds: inout Set<String>) {
        switch node.nodeCases {
        case .window(let window):
            windowIds.insert(String(window.windowId))
        default:
            for child in node.children {
                collectWindowIds(from: child, windowIds: &windowIds)
            }
        }
    }
    
    @MainActor
    private static func computeConfigurationHash() -> String {
        var hasher = SHA256Hasher()
        
        // Hash relevant configuration values that affect layout
        hasher.update(with: String(describing: config.gaps.inner))
        hasher.update(with: String(describing: config.gaps.outer.top))
        hasher.update(with: String(describing: config.gaps.outer.bottom))
        hasher.update(with: String(describing: config.gaps.outer.left))
        hasher.update(with: String(describing: config.gaps.outer.right))
        hasher.update(with: String(describing: config.accordionPadding))
        hasher.update(with: config.defaultRootContainerLayout.rawValue)
        hasher.update(with: String(describing: config.defaultRootContainerOrientation))
        
        return hasher.finalize()
    }
    
    /// Check if this fingerprint is similar to another (for partial cache hits)
    func isSimilarTo(_ other: LayoutFingerprint, threshold: Double = 0.8) -> Bool {
        // Must be same workspace and monitor
        guard workspaceName == other.workspaceName && monitorId == other.monitorId else {
            return false
        }
        
        // Configuration must match exactly
        guard configurationHash == other.configurationHash else {
            return false
        }
        
        // Check structural similarity
        let structuralSimilarity = containerStructure.similarityTo(other.containerStructure)
        let windowSimilarity = windowIds.similarity(to: other.windowIds)
        let rectSimilarity = targetRect.similarityTo(other.targetRect)
        
        let overallSimilarity = (structuralSimilarity + windowSimilarity + rectSimilarity) / 3.0
        return overallSimilarity >= threshold
    }
    
    /// Generate a partial fingerprint that ignores specific windows (for container-level caching)
    func containerLevelFingerprint() -> LayoutFingerprint {
        var copy = self
        copy.windowIds = Set<String>()
        return copy
    }
}

/// Simple SHA256-style hasher for fingerprinting
private struct SHA256Hasher {
    private var data: String = ""
    
    mutating func update(with string: String) {
        data += string + "|"
    }
    
    func finalize() -> String {
        // Simple hash based on string content (in a real implementation, use proper SHA256)
        return String(data.hashValue)
    }
}

// MARK: - Similarity Extensions

extension LayoutFingerprint.ContainerStructureHash {
    func similarityTo(_ other: LayoutFingerprint.ContainerStructureHash) -> Double {
        // Exact match for structure
        if hash == other.hash {
            return 1.0
        }
        
        // Partial similarity based on metrics
        let nodeCountSimilarity = 1.0 - abs(Double(nodeCount - other.nodeCount)) / Double(max(nodeCount, other.nodeCount))
        let depthSimilarity = 1.0 - abs(Double(maxDepth - other.maxDepth)) / Double(max(maxDepth, other.maxDepth, 1))
        let layoutSimilarity = Set(layoutTypes).similarity(to: Set(other.layoutTypes))
        
        return (nodeCountSimilarity + depthSimilarity + layoutSimilarity) / 3.0
    }
}

extension Set where Element == String {
    func similarity(to other: Set<String>) -> Double {
        let intersection = self.intersection(other)
        let union = self.union(other)
        
        guard !union.isEmpty else { return 1.0 } // Both empty
        return Double(intersection.count) / Double(union.count)
    }
}

extension LayoutFingerprint.HashableRect {
    func similarityTo(_ other: LayoutFingerprint.HashableRect) -> Double {
        let widthSimilarity = 1.0 - abs(width - other.width) / max(width, other.width)
        let heightSimilarity = 1.0 - abs(height - other.height) / max(height, other.height)
        
        // Position is less important for layout similarity
        let positionWeight = 0.3
        let sizeWeight = 0.7
        
        let positionSimilarity = 1.0 - (
            abs(topLeftX - other.topLeftX) / max(width, other.width, 1) +
            abs(topLeftY - other.topLeftY) / max(height, other.height, 1)
        ) / 2.0
        
        return sizeWeight * (widthSimilarity + heightSimilarity) / 2.0 + positionWeight * positionSimilarity
    }
}

// MARK: - Fingerprint Cache Management

/// Manages fingerprint-based cache invalidation
@MainActor
class FingerprintCacheManager {
    static let shared = FingerprintCacheManager()
    
    private var lastFingerprints: [String: LayoutFingerprint] = [:]
    
    private init() {}
    
    /// Track the current fingerprint for a workspace
    func updateFingerprint(_ fingerprint: LayoutFingerprint, for workspace: Workspace) {
        lastFingerprints[workspace.name] = fingerprint
    }
    
    /// Check if the workspace layout has changed significantly
    func hasSignificantChange(for workspace: Workspace, newFingerprint: LayoutFingerprint) -> Bool {
        guard let lastFingerprint = lastFingerprints[workspace.name] else {
            return true // No previous fingerprint
        }
        
        // If fingerprints are not similar, we have a significant change
        return !newFingerprint.isSimilarTo(lastFingerprint, threshold: 0.9)
    }
    
    /// Get affected fingerprints when a window changes
    func getAffectedFingerprints(for windowId: CGWindowID) -> [LayoutFingerprint] {
        let windowIdString = String(windowId)
        return lastFingerprints.values.filter { fingerprint in
            fingerprint.windowIds.contains(windowIdString)
        }
    }
    
    /// Clear fingerprints for a workspace
    func clearFingerprints(for workspace: Workspace) {
        lastFingerprints.removeValue(forKey: workspace.name)
    }
    
    /// Get cache statistics
    func getStatistics() -> FingerprintStatistics {
        let totalWorkspaces = lastFingerprints.count
        let avgWindowsPerWorkspace = lastFingerprints.values.reduce(0) { $0 + $1.windowIds.count } / max(1, totalWorkspaces)
        let avgComplexity = lastFingerprints.values.reduce(0.0) { total, fingerprint in
            total + Double(fingerprint.containerStructure.nodeCount)
        } / Double(max(1, totalWorkspaces))
        
        return FingerprintStatistics(
            totalWorkspaces: totalWorkspaces,
            averageWindowsPerWorkspace: avgWindowsPerWorkspace,
            averageComplexity: avgComplexity
        )
    }
}

struct FingerprintStatistics: Sendable {
    let totalWorkspaces: Int
    let averageWindowsPerWorkspace: Int
    let averageComplexity: Double
}