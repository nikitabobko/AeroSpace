import AppKit
import Common

/// Comprehensive performance monitoring and metrics collection system
@MainActor
class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var metrics: PerformanceMetrics
    private var samples: [PerformanceSample] = []
    private var monitoringTask: Task<Void, Never>?
    private let maxSamples: Int

    private init() {
        self.maxSamples = config.performanceConfig.monitoringConfig.maxSamplesRetained
        self.metrics = PerformanceMetrics()

        if config.performanceConfig.monitoringConfig.enableMetrics {
            startMonitoring()
        }
    }

    deinit {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Record a performance event
    func recordEvent(_ event: PerformanceEvent) {
        guard config.performanceConfig.monitoringConfig.enableMetrics else { return }

        let timestamp = Date()

        switch event {
            case .refreshStart(let type):
                metrics.recordRefreshStart(type: type, timestamp: timestamp)

            case .refreshEnd(let type, let duration):
                metrics.recordRefreshEnd(type: type, duration: duration, timestamp: timestamp)

            case .layoutCalculation(let duration, let complexity):
                metrics.recordLayoutCalculation(duration: duration, complexity: complexity, timestamp: timestamp)

            case .cacheHit(let cacheType):
                metrics.recordCacheHit(cacheType: cacheType)

            case .cacheMiss(let cacheType):
                metrics.recordCacheMiss(cacheType: cacheType)

            case .backgroundTaskStart(let taskType):
                metrics.recordBackgroundTaskStart(taskType: taskType, timestamp: timestamp)

            case .backgroundTaskEnd(let taskType, let duration):
                metrics.recordBackgroundTaskEnd(taskType: taskType, duration: duration, timestamp: timestamp)

            case .systemLoadChange(let cpuUsage, let memoryPressure):
                metrics.recordSystemLoad(cpuUsage: cpuUsage, memoryPressure: memoryPressure, timestamp: timestamp)

            case .debouncingDelay(let originalDelay, let adaptiveDelay):
                metrics.recordDebouncingDelay(originalDelay: originalDelay, adaptiveDelay: adaptiveDelay, timestamp: timestamp)
        }

        // Log if debug logging is enabled
        if config.performanceConfig.monitoringConfig.enableDebugLogging {
            logEvent(event)
        }
    }

    /// Get current performance metrics
    func getCurrentMetrics() -> PerformanceMetrics {
        return metrics
    }

    /// Get performance samples for analysis
    func getPerformanceSamples(since: Date? = nil) -> [PerformanceSample] {
        if let since {
            return samples.filter { $0.timestamp >= since }
        }
        return samples
    }

    /// Generate a performance report
    func generateReport(period: TimePeriod = .lastHour) -> PerformanceReport {
        let cutoffTime = Date().addingTimeInterval(-period.timeInterval)
        let relevantSamples = samples.filter { $0.timestamp >= cutoffTime }

        return PerformanceReport(
            period: period,
            samples: relevantSamples,
            metrics: metrics,
            generatedAt: Date(),
        )
    }

    /// Export metrics for external analysis
    func exportMetrics(format: ExportFormat = .json) -> String {
        switch format {
            case .json:
                return exportAsJSON()
            case .csv:
                return exportAsCSV()
            case .prometheus:
                return exportAsPrometheus()
        }
    }

    /// Check for performance regressions
    func detectRegressions() -> [PerformanceRegression] {
        var regressions: [PerformanceRegression] = []

        // Analyze refresh performance
        if let refreshRegression = analyzeRefreshPerformance() {
            regressions.append(refreshRegression)
        }

        // Analyze layout performance
        if let layoutRegression = analyzeLayoutPerformance() {
            regressions.append(layoutRegression)
        }

        // Analyze cache performance
        if let cacheRegression = analyzeCachePerformance() {
            regressions.append(cacheRegression)
        }

        return regressions
    }

    /// Get optimization recommendations
    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []

        // Analyze refresh patterns
        if metrics.refreshMetrics.averageDuration > 100.0 { // > 100ms
            recommendations.append(.optimizeRefreshSpeed)
        }

        // Analyze cache effectiveness
        let cacheHitRate = metrics.cacheMetrics.hitRate
        if cacheHitRate < 0.6 {
            recommendations.append(.improveCacheStrategy)
        }

        // Analyze background task usage
        if metrics.backgroundTaskMetrics.utilizationRate < 0.3 {
            recommendations.append(.increaseBackgroundProcessing)
        }

        // Analyze debouncing effectiveness
        if metrics.debouncingMetrics.efficiency < 0.7 {
            recommendations.append(.tuneAdaptiveDebouncing)
        }

        return recommendations
    }

    /// Reset all metrics and samples
    func reset() {
        metrics = PerformanceMetrics()
        samples.removeAll()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        let interval = config.performanceConfig.monitoringConfig.metricsInterval

        monitoringTask = Task {
            while !Task.isCancelled {
                await collectSystemSample()

                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func collectSystemSample() async {
        let systemMetrics = SystemLoadMonitor.shared.getCurrentMetrics()
        let layoutStats = await BackgroundLayoutCalculator.shared.cache.getStatistics()
        let memoizationStats = LayoutMemoizer.shared.getStatistics()
        let debouncingStats = refreshDebouncer.getStatistics()

        let sample = PerformanceSample(
            timestamp: Date(),
            systemLoad: systemMetrics.currentCPUUsage,
            memoryUsage: systemMetrics.memoryPressure.rawValue,
            layoutCacheStats: layoutStats,
            memoizationStats: memoizationStats,
            debouncingStats: debouncingStats,
        )

        samples.append(sample)

        // Keep samples within limit
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    private func logEvent(_ event: PerformanceEvent) {
        let message = formatEventForLogging(event)
        print("PerformanceMonitor: \(message)")
    }

    private func formatEventForLogging(_ event: PerformanceEvent) -> String {
        switch event {
            case .refreshStart(let type):
                return "Refresh started: \(type)"
            case .refreshEnd(let type, let duration):
                return "Refresh completed: \(type), duration: \(String(format: "%.2f", duration))ms"
            case .layoutCalculation(let duration, let complexity):
                return "Layout calculation: \(String(format: "%.2f", duration))ms, complexity: \(complexity)"
            case .cacheHit(let cacheType):
                return "Cache hit: \(cacheType)"
            case .cacheMiss(let cacheType):
                return "Cache miss: \(cacheType)"
            case .backgroundTaskStart(let taskType):
                return "Background task started: \(taskType)"
            case .backgroundTaskEnd(let taskType, let duration):
                return "Background task completed: \(taskType), duration: \(String(format: "%.2f", duration))ms"
            case .systemLoadChange(let cpu, let memory):
                return "System load: CPU \(String(format: "%.1f", cpu * 100))%, Memory pressure: \(memory)"
            case .debouncingDelay(let original, let adaptive):
                return "Debouncing: \(String(format: "%.1f", original * 1000))ms -> \(String(format: "%.1f", adaptive * 1000))ms"
        }
    }

    private func exportAsJSON() -> String {
        // Simplified JSON export
        let reportData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "refresh_metrics": [
                "total_operations": metrics.refreshMetrics.totalOperations,
                "average_duration": metrics.refreshMetrics.averageDuration,
                "success_rate": metrics.refreshMetrics.successRate,
            ],
            "cache_metrics": [
                "hit_rate": metrics.cacheMetrics.hitRate,
                "total_hits": metrics.cacheMetrics.totalHits,
                "total_misses": metrics.cacheMetrics.totalMisses,
            ],
            "background_metrics": [
                "utilization_rate": metrics.backgroundTaskMetrics.utilizationRate,
                "average_task_duration": metrics.backgroundTaskMetrics.averageTaskDuration,
                "total_tasks": metrics.backgroundTaskMetrics.totalTasks,
            ],
        ]

        // In a real implementation, use JSONSerialization
        return "{\n  \"performance_metrics\": \(reportData)\n}"
    }

    private func exportAsCSV() -> String {
        var csv = "timestamp,cpu_usage,memory_pressure,refresh_duration,cache_hit_rate\n"

        for sample in samples.suffix(100) { // Last 100 samples
            csv += "\(sample.timestamp),\(sample.systemLoad),\(sample.memoryUsage),"
            csv += "\(sample.layoutCacheStats.hitRate),\(sample.memoizationStats.hitRate)\n"
        }

        return csv
    }

    private func exportAsPrometheus() -> String {
        var prometheus = "# HELP aerospace_refresh_duration_ms Duration of refresh operations\n"
        prometheus += "# TYPE aerospace_refresh_duration_ms gauge\n"
        prometheus += "aerospace_refresh_duration_ms \(metrics.refreshMetrics.averageDuration)\n"

        prometheus += "# HELP aerospace_cache_hit_rate Cache hit rate\n"
        prometheus += "# TYPE aerospace_cache_hit_rate gauge\n"
        prometheus += "aerospace_cache_hit_rate \(metrics.cacheMetrics.hitRate)\n"

        return prometheus
    }

    private func analyzeRefreshPerformance() -> PerformanceRegression? {
        let recentSamples = samples.suffix(20)
        let olderSamples = samples.dropLast(20).suffix(20)

        guard !recentSamples.isEmpty && !olderSamples.isEmpty else { return nil }

        let recentAvg = recentSamples.reduce(0.0) { $0 + $1.systemLoad } / Double(recentSamples.count)
        let olderAvg = olderSamples.reduce(0.0) { $0 + $1.systemLoad } / Double(olderSamples.count)

        let regressionThreshold = 1.5 // 50% slower
        if recentAvg > olderAvg * regressionThreshold {
            return PerformanceRegression(
                type: .refreshPerformance,
                severity: .major,
                description: "Refresh performance has degraded by \(String(format: "%.1f", (recentAvg / olderAvg - 1) * 100))%",
                detectedAt: Date(),
            )
        }

        return nil
    }

    private func analyzeLayoutPerformance() -> PerformanceRegression? {
        // Simplified layout performance analysis
        if metrics.layoutMetrics.averageDuration > 200.0 { // > 200ms
            return PerformanceRegression(
                type: .layoutPerformance,
                severity: .minor,
                description: "Layout calculations are taking longer than expected",
                detectedAt: Date(),
            )
        }

        return nil
    }

    private func analyzeCachePerformance() -> PerformanceRegression? {
        if metrics.cacheMetrics.hitRate < 0.5 {
            return PerformanceRegression(
                type: .cachePerformance,
                severity: .minor,
                description: "Cache hit rate is below optimal threshold",
                detectedAt: Date(),
            )
        }

        return nil
    }
}

// MARK: - Supporting Types

enum PerformanceEvent {
    case refreshStart(String)
    case refreshEnd(String, TimeInterval)
    case layoutCalculation(duration: TimeInterval, complexity: Double)
    case cacheHit(String)
    case cacheMiss(String)
    case backgroundTaskStart(String)
    case backgroundTaskEnd(String, TimeInterval)
    case systemLoadChange(cpuUsage: Double, memoryPressure: Int)
    case debouncingDelay(originalDelay: TimeInterval, adaptiveDelay: TimeInterval)
}

enum TimePeriod {
    case lastMinute
    case lastHour
    case lastDay
    case lastWeek

    var timeInterval: TimeInterval {
        switch self {
            case .lastMinute: return 60
            case .lastHour: return 3600
            case .lastDay: return 86400
            case .lastWeek: return 604_800
        }
    }
}

enum ExportFormat {
    case json
    case csv
    case prometheus
}

enum OptimizationRecommendation: String {
    case optimizeRefreshSpeed = "Optimize refresh operation speed"
    case improveCacheStrategy = "Improve cache hit rate"
    case increaseBackgroundProcessing = "Increase background task utilization"
    case tuneAdaptiveDebouncing = "Tune adaptive debouncing parameters"
    case reduceLayoutComplexity = "Reduce layout calculation complexity"
    case optimizeMemoryUsage = "Optimize memory usage patterns"
}

struct PerformanceRegression {
    let type: RegressionType
    let severity: Severity
    let description: String
    let detectedAt: Date

    enum RegressionType {
        case refreshPerformance
        case layoutPerformance
        case cachePerformance
        case memoryUsage
        case cpuUsage
    }

    enum Severity {
        case minor
        case major
        case critical
    }
}

struct PerformanceSample: Sendable {
    let timestamp: Date
    let systemLoad: Double
    let memoryUsage: Int
    let layoutCacheStats: CacheStatistics
    let memoizationStats: MemoizationStatistics
    let debouncingStats: DebouncingStatistics
}

struct PerformanceReport {
    let period: TimePeriod
    let samples: [PerformanceSample]
    let metrics: PerformanceMetrics
    let generatedAt: Date
}
