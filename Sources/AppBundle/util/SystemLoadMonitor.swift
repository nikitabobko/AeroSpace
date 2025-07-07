import AppKit
import Common
import Darwin

/// Monitors system performance metrics for adaptive performance optimizations
@MainActor
class SystemLoadMonitor {
    static let shared = SystemLoadMonitor()

    private var cpuUsageHistory: [CPUUsageSample] = []
    private var memoryPressureHistory: [MemoryPressureSample] = []
    private var operationFrequencyHistory: [OperationFrequencySample] = []

    private let maxHistorySize = 60 // Keep 60 samples (1 minute at 1Hz)
    private var monitoringTask: Task<Void, Never>?

    private struct CPUUsageSample {
        let timestamp: Date
        let userPercent: Double
        let systemPercent: Double
        let idlePercent: Double

        var totalUsage: Double {
            userPercent + systemPercent
        }
    }

    private struct MemoryPressureSample {
        let timestamp: Date
        let pressureLevel: MemoryPressureLevel
        let availableMemoryMB: Double
        let memoryUsagePercent: Double
    }

    enum MemoryPressureLevel: Int, CaseIterable {
        case normal = 0
        case warning = 1
        case urgent = 2
        case critical = 3
    }

    private struct OperationFrequencySample {
        let timestamp: Date
        let operationsPerSecond: Double
        let operationType: String
    }

    struct SystemLoadMetrics: Sendable {
        let currentCPUUsage: Double
        let averageCPUUsage: Double
        let cpuTrend: LoadTrend
        let memoryPressure: MemoryPressureLevel
        let operationFrequency: Double
        let systemHealthScore: Double // 0.0 = poor, 1.0 = excellent

        enum LoadTrend {
            case decreasing
            case stable
            case increasing
        }
    }

    private init() {
        startMonitoring()
    }

    deinit {
        // Note: stopMonitoring() will be called automatically when the actor is deallocated
        monitoringTask?.cancel()
    }

    /// Get current system load metrics
    func getCurrentMetrics() -> SystemLoadMetrics {
        let currentCPU = getCurrentCPUUsage()
        let avgCPU = getAverageCPUUsage()
        let cpuTrend = getCPUTrend()
        let memoryPressure = getCurrentMemoryPressure()
        let operationFreq = getRecentOperationFrequency()
        let healthScore = calculateSystemHealthScore()

        return SystemLoadMetrics(
            currentCPUUsage: currentCPU,
            averageCPUUsage: avgCPU,
            cpuTrend: cpuTrend,
            memoryPressure: memoryPressure,
            operationFrequency: operationFreq,
            systemHealthScore: healthScore,
        )
    }

    /// Record an operation for frequency tracking
    func recordOperation(type: String = "layout") {
        let now = Date()

        // Count recent operations of the same type
        let recentOps = operationFrequencyHistory.filter { sample in
            sample.operationType == type && now.timeIntervalSince(sample.timestamp) < 1.0
        }

        let frequency = Double(recentOps.count + 1) // +1 for current operation

        let sample = OperationFrequencySample(
            timestamp: now,
            operationsPerSecond: frequency,
            operationType: type,
        )

        operationFrequencyHistory.append(sample)

        // Keep history size manageable
        if operationFrequencyHistory.count > maxHistorySize {
            operationFrequencyHistory.removeFirst()
        }
    }

    /// Get recommended debounce delay based on current system state
    func getRecommendedDebounceDelay(baseDelay: TimeInterval = 0.05) -> TimeInterval {
        let metrics = getCurrentMetrics()

        // Base delay adjustment factors
        var delayMultiplier = 1.0

        // Adjust based on CPU usage
        if metrics.currentCPUUsage > 0.8 {
            delayMultiplier *= 2.0 // Double delay under high CPU
        } else if metrics.currentCPUUsage > 0.6 {
            delayMultiplier *= 1.5
        } else if metrics.currentCPUUsage < 0.3 {
            delayMultiplier *= 0.8 // Reduce delay under low CPU
        }

        // Adjust based on CPU trend
        switch metrics.cpuTrend {
            case .increasing:
                delayMultiplier *= 1.3
            case .decreasing:
                delayMultiplier *= 0.9
            case .stable:
                break // No adjustment
        }

        // Adjust based on memory pressure
        switch metrics.memoryPressure {
            case .critical:
                delayMultiplier *= 3.0
            case .urgent:
                delayMultiplier *= 2.0
            case .warning:
                delayMultiplier *= 1.5
            case .normal:
                break
        }

        // Adjust based on operation frequency
        if metrics.operationFrequency > 5.0 {
            delayMultiplier *= 1.5 // Increase delay if operations are very frequent
        }

        // Apply system health score
        delayMultiplier *= (2.0 - metrics.systemHealthScore) // Poor health = higher multiplier

        // Clamp to reasonable bounds
        delayMultiplier = max(0.2, min(5.0, delayMultiplier))

        return baseDelay * delayMultiplier
    }

    /// Determine if system is under high load
    func isSystemUnderHighLoad() -> Bool {
        let metrics = getCurrentMetrics()
        return metrics.currentCPUUsage > 0.7 ||
            metrics.memoryPressure.rawValue >= MemoryPressureLevel.urgent.rawValue ||
            metrics.systemHealthScore < 0.4
    }

    /// Get performance recommendations
    func getPerformanceRecommendations() -> [PerformanceRecommendation] {
        let metrics = getCurrentMetrics()
        var recommendations: [PerformanceRecommendation] = []

        if metrics.currentCPUUsage > 0.8 {
            recommendations.append(.reduceCPUIntensiveOperations)
        }

        if metrics.memoryPressure.rawValue >= MemoryPressureLevel.warning.rawValue {
            recommendations.append(.reduceMemoryUsage)
        }

        if metrics.operationFrequency > 10.0 {
            recommendations.append(.increaseDebouncingDelay)
        }

        if metrics.cpuTrend == .increasing && metrics.currentCPUUsage > 0.5 {
            recommendations.append(.enableBackgroundProcessing)
        }

        if metrics.systemHealthScore < 0.3 {
            recommendations.append(.disableNonEssentialOptimizations)
        }

        return recommendations
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                updateCPUUsage()
                updateMemoryPressure()

                // Sample every second
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func updateCPUUsage() {
        let usage = sampleCPUUsage()
        cpuUsageHistory.append(usage)

        if cpuUsageHistory.count > maxHistorySize {
            cpuUsageHistory.removeFirst()
        }
    }

    private func updateMemoryPressure() {
        let pressure = sampleMemoryPressure()
        memoryPressureHistory.append(pressure)

        if memoryPressureHistory.count > maxHistorySize {
            memoryPressureHistory.removeFirst()
        }
    }

    private func sampleCPUUsage() -> CPUUsageSample {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            // Fallback to estimated values
            return CPUUsageSample(
                timestamp: Date(),
                userPercent: 0.1,
                systemPercent: 0.05,
                idlePercent: 0.85,
            )
        }

        let totalTicks = info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3

        guard totalTicks > 0 else {
            return CPUUsageSample(timestamp: Date(), userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        let userPercent = Double(info.cpu_ticks.0) / Double(totalTicks)
        let systemPercent = Double(info.cpu_ticks.1) / Double(totalTicks)
        let idlePercent = Double(info.cpu_ticks.2) / Double(totalTicks)

        return CPUUsageSample(
            timestamp: Date(),
            userPercent: userPercent,
            systemPercent: systemPercent,
            idlePercent: idlePercent,
        )
    }

    private func sampleMemoryPressure() -> MemoryPressureSample {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryPressureSample(
                timestamp: Date(),
                pressureLevel: .normal,
                availableMemoryMB: 1000.0,
                memoryUsagePercent: 0.5,
            )
        }

        let pageSize = UInt(getpagesize())
        let totalPages = info.free_count + info.active_count + info.inactive_count + info.wire_count
        let freePages = info.free_count
        let usagePercent = Double(totalPages - freePages) / Double(totalPages)

        let availableMemoryMB = Double(UInt(freePages) * pageSize) / (1024 * 1024)

        let pressureLevel: MemoryPressureLevel = if usagePercent > 0.95 {
            .critical
        } else if usagePercent > 0.85 {
            .urgent
        } else if usagePercent > 0.75 {
            .warning
        } else {
            .normal
        }

        return MemoryPressureSample(
            timestamp: Date(),
            pressureLevel: pressureLevel,
            availableMemoryMB: availableMemoryMB,
            memoryUsagePercent: usagePercent,
        )
    }

    private func getCurrentCPUUsage() -> Double {
        guard let latest = cpuUsageHistory.last else { return 0.0 }
        return latest.totalUsage
    }

    private func getAverageCPUUsage() -> Double {
        guard !cpuUsageHistory.isEmpty else { return 0.0 }

        let recent = cpuUsageHistory.suffix(10) // Last 10 seconds
        let totalUsage = recent.reduce(0.0) { $0 + $1.totalUsage }
        return totalUsage / Double(recent.count)
    }

    private func getCPUTrend() -> SystemLoadMetrics.LoadTrend {
        guard cpuUsageHistory.count >= 5 else { return .stable }

        let recent = cpuUsageHistory.suffix(5)
        let usages = recent.map { $0.totalUsage }

        // Simple trend analysis using linear regression slope
        let n = Double(usages.count)
        let sumX = n * (n - 1) / 2 // 0 + 1 + 2 + ... + (n-1)
        let sumY = usages.reduce(0, +)
        let sumXY = usages.enumerated().reduce(0.0) { sum, item in
            sum + Double(item.offset) * item.element
        }
        let sumX2 = (n - 1) * n * (2 * n - 1) / 6 // 0² + 1² + 2² + ... + (n-1)²

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)

        if slope > 0.02 {
            return .increasing
        } else if slope < -0.02 {
            return .decreasing
        } else {
            return .stable
        }
    }

    private func getCurrentMemoryPressure() -> MemoryPressureLevel {
        return memoryPressureHistory.last?.pressureLevel ?? .normal
    }

    private func getRecentOperationFrequency() -> Double {
        let now = Date()
        let recentOps = operationFrequencyHistory.filter { sample in
            now.timeIntervalSince(sample.timestamp) < 5.0 // Last 5 seconds
        }

        guard !recentOps.isEmpty else { return 0.0 }

        return recentOps.reduce(0.0) { $0 + $1.operationsPerSecond } / Double(recentOps.count)
    }

    private func calculateSystemHealthScore() -> Double {
        let cpuScore = max(0.0, 1.0 - getCurrentCPUUsage())
        let memoryScore = max(0.0, 1.0 - Double(getCurrentMemoryPressure().rawValue) / 3.0)
        let frequencyScore = max(0.0, 1.0 - getRecentOperationFrequency() / 20.0)

        return (cpuScore + memoryScore + frequencyScore) / 3.0
    }
}

enum PerformanceRecommendation: String, CaseIterable {
    case reduceCPUIntensiveOperations = "Reduce CPU-intensive operations"
    case reduceMemoryUsage = "Reduce memory usage"
    case increaseDebouncingDelay = "Increase debouncing delay"
    case enableBackgroundProcessing = "Enable background processing"
    case disableNonEssentialOptimizations = "Disable non-essential optimizations"
    case useSimplifiedLayouts = "Use simplified layouts"
    case reduceCacheSize = "Reduce cache size"
}
