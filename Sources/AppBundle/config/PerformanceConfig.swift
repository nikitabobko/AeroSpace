import AppKit
import Common

/// Configuration options for performance optimizations
struct PerformanceConfig: ConvenienceCopyable {
    /// Enable background layout calculations for complex workspaces
    var useBackgroundLayoutCalculation: Bool = true

    /// Enable layout memoization to cache expensive calculations
    var useLayoutMemoization: Bool = true

    /// Enable adaptive debouncing based on system load
    var useAdaptiveDebouncing: Bool = true

    /// Minimum number of windows to trigger background layout
    var backgroundLayoutThreshold: Int = 10

    /// Maximum cache size for layout memoization (number of entries)
    var layoutCacheSize: Int = 100

    /// Cache timeout for layout results (seconds)
    var layoutCacheTimeout: TimeInterval = 30.0

    /// Debouncing configuration
    var debouncingConfig: DebouncingConfig = DebouncingConfig()

    /// Performance monitoring options
    var monitoringConfig: MonitoringConfig = MonitoringConfig()
}

struct DebouncingConfig: ConvenienceCopyable {
    /// Base debounce delay (milliseconds)
    var baseDelay: Double = 50.0

    /// Minimum debounce delay (milliseconds)
    var minimumDelay: Double = 10.0

    /// Maximum debounce delay (milliseconds)
    var maximumDelay: Double = 200.0

    /// Factor to adjust delay based on CPU load (0.5 - 2.0)
    var cpuLoadFactor: Double = 1.5

    /// Factor to adjust delay based on operation frequency (0.5 - 2.0)
    var frequencyFactor: Double = 1.2
}

struct MonitoringConfig: ConvenienceCopyable {
    /// Enable performance metrics collection
    var enableMetrics: Bool = false

    /// Enable debug logging for performance operations
    var enableDebugLogging: Bool = false

    /// Metrics collection interval (seconds)
    var metricsInterval: TimeInterval = 60.0

    /// Maximum number of performance samples to keep
    var maxSamplesRetained: Int = 1000
}

extension PerformanceConfig {
    /// Get effective debounce delay based on current system state
    func getEffectiveDebounceDelay(
        cpuLoad: Double = 0.0,
        operationFrequency: Double = 0.0,
    ) -> TimeInterval {
        guard useAdaptiveDebouncing else {
            return debouncingConfig.baseDelay / 1000.0
        }

        var delay = debouncingConfig.baseDelay

        // Adjust based on CPU load (higher load = longer delay)
        if cpuLoad > 0.5 {
            delay *= debouncingConfig.cpuLoadFactor
        }

        // Adjust based on operation frequency (higher frequency = longer delay)
        if operationFrequency > 1.0 {
            delay *= debouncingConfig.frequencyFactor
        }

        // Clamp to min/max bounds
        delay = max(debouncingConfig.minimumDelay, min(debouncingConfig.maximumDelay, delay))

        return delay / 1000.0 // Convert to seconds
    }

    /// Determine if background layout should be used based on complexity
    func shouldUseBackgroundLayout(windowCount: Int, containerDepth: Int = 0) -> Bool {
        guard useBackgroundLayoutCalculation else { return false }

        // Use background layout for complex scenarios
        return windowCount >= backgroundLayoutThreshold || containerDepth > 3
    }

    /// Determine if layout memoization should be used
    func shouldUseMemoization(operationType: String) -> Bool {
        guard useLayoutMemoization else { return false }

        // Always use memoization for layout operations
        return operationType.contains("layout") || operationType.contains("resize")
    }
}

/// Performance preset configurations
extension PerformanceConfig {
    /// High performance preset - optimized for speed
    static var highPerformance: PerformanceConfig {
        var config = PerformanceConfig()
        config.useBackgroundLayoutCalculation = true
        config.useLayoutMemoization = true
        config.useAdaptiveDebouncing = true
        config.backgroundLayoutThreshold = 5
        config.layoutCacheSize = 200
        config.debouncingConfig.baseDelay = 25.0
        config.debouncingConfig.minimumDelay = 5.0
        return config
    }

    /// Balanced preset - good performance with reasonable resource usage
    static var balanced: PerformanceConfig {
        return PerformanceConfig() // Default values are balanced
    }

    /// Memory efficient preset - optimized for low memory usage
    static var memoryEfficient: PerformanceConfig {
        var config = PerformanceConfig()
        config.useBackgroundLayoutCalculation = false
        config.useLayoutMemoization = true
        config.useAdaptiveDebouncing = true
        config.backgroundLayoutThreshold = 20
        config.layoutCacheSize = 25
        config.layoutCacheTimeout = 10.0
        return config
    }

    /// Debug preset - with extensive monitoring
    static var debug: PerformanceConfig {
        var config = PerformanceConfig.balanced
        config.monitoringConfig.enableMetrics = true
        config.monitoringConfig.enableDebugLogging = true
        config.monitoringConfig.metricsInterval = 10.0
        return config
    }
}
