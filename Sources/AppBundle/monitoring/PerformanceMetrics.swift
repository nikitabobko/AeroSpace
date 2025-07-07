import AppKit
import Common

/// Comprehensive performance metrics collection
struct PerformanceMetrics: Sendable {
    private(set) var refreshMetrics: RefreshMetrics
    private(set) var layoutMetrics: LayoutMetrics
    private(set) var cacheMetrics: CacheMetrics
    private(set) var backgroundTaskMetrics: BackgroundTaskMetrics
    private(set) var systemMetrics: SystemMetrics
    private(set) var debouncingMetrics: DebouncingMetrics

    init() {
        self.refreshMetrics = RefreshMetrics()
        self.layoutMetrics = LayoutMetrics()
        self.cacheMetrics = CacheMetrics()
        self.backgroundTaskMetrics = BackgroundTaskMetrics()
        self.systemMetrics = SystemMetrics()
        self.debouncingMetrics = DebouncingMetrics()
    }

    // MARK: - Recording Methods

    mutating func recordRefreshStart(type: String, timestamp: Date) {
        refreshMetrics.recordStart(type: type, timestamp: timestamp)
    }

    mutating func recordRefreshEnd(type: String, duration: TimeInterval, timestamp: Date) {
        refreshMetrics.recordEnd(type: type, duration: duration, timestamp: timestamp)
    }

    mutating func recordLayoutCalculation(duration: TimeInterval, complexity: Double, timestamp: Date) {
        layoutMetrics.recordCalculation(duration: duration, complexity: complexity, timestamp: timestamp)
    }

    mutating func recordCacheHit(cacheType: String) {
        cacheMetrics.recordHit(cacheType: cacheType)
    }

    mutating func recordCacheMiss(cacheType: String) {
        cacheMetrics.recordMiss(cacheType: cacheType)
    }

    mutating func recordBackgroundTaskStart(taskType: String, timestamp: Date) {
        backgroundTaskMetrics.recordTaskStart(taskType: taskType, timestamp: timestamp)
    }

    mutating func recordBackgroundTaskEnd(taskType: String, duration: TimeInterval, timestamp: Date) {
        backgroundTaskMetrics.recordTaskEnd(taskType: taskType, duration: duration, timestamp: timestamp)
    }

    mutating func recordSystemLoad(cpuUsage: Double, memoryPressure: Int, timestamp: Date) {
        systemMetrics.recordSystemLoad(cpuUsage: cpuUsage, memoryPressure: memoryPressure, timestamp: timestamp)
    }

    mutating func recordDebouncingDelay(originalDelay: TimeInterval, adaptiveDelay: TimeInterval, timestamp: Date) {
        debouncingMetrics.recordDelay(originalDelay: originalDelay, adaptiveDelay: adaptiveDelay, timestamp: timestamp)
    }
}

// MARK: - Refresh Metrics

struct RefreshMetrics: Sendable {
    private(set) var totalOperations: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var successfulOperations: Int = 0
    private(set) var failedOperations: Int = 0
    private(set) var operationTypes: [String: Int] = [:]
    private(set) var lastOperationTime: Date?

    var averageDuration: TimeInterval {
        guard totalOperations > 0 else { return 0 }
        return totalDuration / Double(totalOperations)
    }

    var successRate: Double {
        guard totalOperations > 0 else { return 1.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }

    var operationsPerSecond: Double {
        guard let lastTime = lastOperationTime else { return 0 }
        let timeDiff = Date().timeIntervalSince(lastTime)
        guard timeDiff > 0 else { return 0 }
        return Double(totalOperations) / timeDiff
    }

    mutating func recordStart(type: String, timestamp: Date) {
        operationTypes[type, default: 0] += 1
        lastOperationTime = timestamp
    }

    mutating func recordEnd(type: String, duration: TimeInterval, timestamp: Date) {
        totalOperations += 1
        totalDuration += duration

        if duration >= 0 { // Assuming non-negative duration means success
            successfulOperations += 1
        } else {
            failedOperations += 1
        }
    }
}

// MARK: - Layout Metrics

struct LayoutMetrics: Sendable {
    private(set) var totalCalculations: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var totalComplexity: Double = 0
    private(set) var complexityDistribution: [ComplexityRange: Int] = [:]

    enum ComplexityRange: CaseIterable {
        case low        // 0-10 nodes
        case medium     // 11-50 nodes
        case high       // 51-100 nodes
        case veryHigh   // 100+ nodes

        func contains(_ complexity: Double) -> Bool {
            switch self {
                case .low: return complexity <= 10
                case .medium: return complexity > 10 && complexity <= 50
                case .high: return complexity > 50 && complexity <= 100
                case .veryHigh: return complexity > 100
            }
        }
    }

    var averageDuration: TimeInterval {
        guard totalCalculations > 0 else { return 0 }
        return totalDuration / Double(totalCalculations)
    }

    var averageComplexity: Double {
        guard totalCalculations > 0 else { return 0 }
        return totalComplexity / Double(totalCalculations)
    }

    var calculationsPerSecond: Double {
        // Simplified calculation - in real implementation, track time window
        return Double(totalCalculations) / max(1, totalDuration)
    }

    mutating func recordCalculation(duration: TimeInterval, complexity: Double, timestamp: Date) {
        totalCalculations += 1
        totalDuration += duration
        totalComplexity += complexity

        // Update complexity distribution
        for range in ComplexityRange.allCases {
            if range.contains(complexity) {
                complexityDistribution[range, default: 0] += 1
                break
            }
        }
    }
}

// MARK: - Cache Metrics

struct CacheMetrics: Sendable {
    private(set) var totalHits: Int = 0
    private(set) var totalMisses: Int = 0
    private(set) var hitsByType: [String: Int] = [:]
    private(set) var missesByType: [String: Int] = [:]

    var totalRequests: Int {
        totalHits + totalMisses
    }

    var hitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalHits) / Double(totalRequests)
    }

    var missRate: Double {
        1.0 - hitRate
    }

    func hitRateForType(_ type: String) -> Double {
        let hits = hitsByType[type] ?? 0
        let misses = missesByType[type] ?? 0
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }

    mutating func recordHit(cacheType: String) {
        totalHits += 1
        hitsByType[cacheType, default: 0] += 1
    }

    mutating func recordMiss(cacheType: String) {
        totalMisses += 1
        missesByType[cacheType, default: 0] += 1
    }
}

// MARK: - Background Task Metrics

struct BackgroundTaskMetrics: Sendable {
    private(set) var totalTasks: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var activeTasks: Int = 0
    private(set) var tasksByType: [String: TaskTypeMetrics] = [:]

    struct TaskTypeMetrics: Sendable {
        var count: Int = 0
        var totalDuration: TimeInterval = 0
        var averageDuration: TimeInterval {
            guard count > 0 else { return 0 }
            return totalDuration / Double(count)
        }
    }

    var averageTaskDuration: TimeInterval {
        guard totalTasks > 0 else { return 0 }
        return totalDuration / Double(totalTasks)
    }

    var utilizationRate: Double {
        // Simplified utilization - percentage of time background tasks are running
        // In real implementation, this would be calculated over a time window
        return min(1.0, Double(activeTasks) / 4.0) // Assuming max 4 concurrent tasks
    }

    var tasksPerSecond: Double {
        // Simplified rate calculation
        return Double(totalTasks) / max(1, totalDuration)
    }

    mutating func recordTaskStart(taskType: String, timestamp: Date) {
        activeTasks += 1
    }

    mutating func recordTaskEnd(taskType: String, duration: TimeInterval, timestamp: Date) {
        totalTasks += 1
        totalDuration += duration
        activeTasks = max(0, activeTasks - 1)

        var typeMetrics = tasksByType[taskType] ?? TaskTypeMetrics()
        typeMetrics.count += 1
        typeMetrics.totalDuration += duration
        tasksByType[taskType] = typeMetrics
    }
}

// MARK: - System Metrics

struct SystemMetrics: Sendable {
    private(set) var cpuUsageHistory: [Double] = []
    private(set) var memoryPressureHistory: [Int] = []
    private(set) var lastUpdateTime: Date?

    private let maxHistorySize = 100

    var averageCPUUsage: Double {
        guard !cpuUsageHistory.isEmpty else { return 0 }
        return cpuUsageHistory.reduce(0, +) / Double(cpuUsageHistory.count)
    }

    var currentCPUUsage: Double {
        cpuUsageHistory.last ?? 0
    }

    var averageMemoryPressure: Double {
        guard !memoryPressureHistory.isEmpty else { return 0 }
        let total = memoryPressureHistory.reduce(0, +)
        return Double(total) / Double(memoryPressureHistory.count)
    }

    var currentMemoryPressure: Int {
        memoryPressureHistory.last ?? 0
    }

    mutating func recordSystemLoad(cpuUsage: Double, memoryPressure: Int, timestamp: Date) {
        cpuUsageHistory.append(cpuUsage)
        memoryPressureHistory.append(memoryPressure)

        // Keep history size manageable
        if cpuUsageHistory.count > maxHistorySize {
            cpuUsageHistory.removeFirst()
        }
        if memoryPressureHistory.count > maxHistorySize {
            memoryPressureHistory.removeFirst()
        }

        lastUpdateTime = timestamp
    }
}

// MARK: - Debouncing Metrics

struct DebouncingMetrics: Sendable {
    private(set) var totalDelays: Int = 0
    private(set) var totalOriginalDelay: TimeInterval = 0
    private(set) var totalAdaptiveDelay: TimeInterval = 0
    private(set) var adaptationHistory: [AdaptationRecord] = []

    struct AdaptationRecord: Sendable {
        let timestamp: Date
        let originalDelay: TimeInterval
        let adaptiveDelay: TimeInterval
        let adaptationRatio: Double
    }

    private let maxHistorySize = 200

    var averageOriginalDelay: TimeInterval {
        guard totalDelays > 0 else { return 0 }
        return totalOriginalDelay / Double(totalDelays)
    }

    var averageAdaptiveDelay: TimeInterval {
        guard totalDelays > 0 else { return 0 }
        return totalAdaptiveDelay / Double(totalDelays)
    }

    var adaptationRatio: Double {
        guard averageOriginalDelay > 0 else { return 1.0 }
        return averageAdaptiveDelay / averageOriginalDelay
    }

    var efficiency: Double {
        // Efficiency based on how well adaptive delays match system needs
        // This is a simplified calculation - in practice, would correlate with performance outcomes
        let recentAdaptations = adaptationHistory.suffix(20)
        guard !recentAdaptations.isEmpty else { return 1.0 }

        let ratioVariance = calculateVariance(recentAdaptations.map { $0.adaptationRatio })

        // Lower variance indicates more consistent adaptation = higher efficiency
        return max(0.0, 1.0 - ratioVariance)
    }

    mutating func recordDelay(originalDelay: TimeInterval, adaptiveDelay: TimeInterval, timestamp: Date) {
        totalDelays += 1
        totalOriginalDelay += originalDelay
        totalAdaptiveDelay += adaptiveDelay

        let adaptationRatio = originalDelay > 0 ? adaptiveDelay / originalDelay : 1.0
        let record = AdaptationRecord(
            timestamp: timestamp,
            originalDelay: originalDelay,
            adaptiveDelay: adaptiveDelay,
            adaptationRatio: adaptationRatio,
        )

        adaptationHistory.append(record)

        // Keep history size manageable
        if adaptationHistory.count > maxHistorySize {
            adaptationHistory.removeFirst()
        }
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0.0, +) / Double(values.count)
    }
}

// MARK: - Aggregated Performance Summary

extension PerformanceMetrics {
    /// Generate an overall performance health score (0.0 = poor, 1.0 = excellent)
    var overallHealthScore: Double {
        let refreshScore = min(1.0, refreshMetrics.successRate)
        let layoutScore = layoutMetrics.averageDuration < 100.0 ? 1.0 : max(0.0, 1.0 - (layoutMetrics.averageDuration - 100.0) / 200.0)
        let cacheScore = cacheMetrics.hitRate
        let systemScore = max(0.0, 1.0 - systemMetrics.averageCPUUsage)
        let debouncingScore = debouncingMetrics.efficiency

        return (refreshScore + layoutScore + cacheScore + systemScore + debouncingScore) / 5.0
    }

    /// Get the most critical performance issues
    var criticalIssues: [String] {
        var issues: [String] = []

        if refreshMetrics.successRate < 0.9 {
            issues.append("Low refresh success rate: \(String(format: "%.1f", refreshMetrics.successRate * 100))%")
        }

        if layoutMetrics.averageDuration > 200.0 {
            issues.append("Slow layout calculations: \(String(format: "%.1f", layoutMetrics.averageDuration))ms avg")
        }

        if cacheMetrics.hitRate < 0.5 {
            issues.append("Poor cache performance: \(String(format: "%.1f", cacheMetrics.hitRate * 100))% hit rate")
        }

        if systemMetrics.averageCPUUsage > 0.8 {
            issues.append("High CPU usage: \(String(format: "%.1f", systemMetrics.averageCPUUsage * 100))%")
        }

        return issues
    }

    /// Get performance strengths
    var strengths: [String] {
        var strengths: [String] = []

        if refreshMetrics.successRate > 0.98 {
            strengths.append("Excellent refresh reliability")
        }

        if layoutMetrics.averageDuration < 50.0 {
            strengths.append("Fast layout calculations")
        }

        if cacheMetrics.hitRate > 0.8 {
            strengths.append("Effective caching")
        }

        if backgroundTaskMetrics.utilizationRate > 0.7 {
            strengths.append("Good background task utilization")
        }

        if debouncingMetrics.efficiency > 0.8 {
            strengths.append("Efficient adaptive debouncing")
        }

        return strengths
    }
}
