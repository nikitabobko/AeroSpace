import AppKit
import Common

/// Advanced debouncer that adapts delay based on system load and operation patterns
@MainActor
final class AdaptiveDebouncer {
    private var pendingTask: Task<Void, Never>?
    private var pendingEvent: RefreshSessionEvent?
    private let baseDelay: TimeInterval
    private var lastOperationTime = Date.distantPast
    private var operationHistory: [OperationRecord] = []

    private struct OperationRecord {
        let timestamp: Date
        let eventType: RefreshSessionEvent
        let computedDelay: TimeInterval
        let systemLoad: Double
    }

    init(baseDelay: TimeInterval = 0.05) {
        self.baseDelay = baseDelay
    }

    /// Debounce with adaptive delay calculation
    func debounce(
        event: RefreshSessionEvent,
        screenIsDefinitelyUnlocked: Bool,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) {
        // Record this operation for pattern analysis
        SystemLoadMonitor.shared.recordOperation(type: "refresh")

        // Calculate adaptive delay
        let adaptiveDelay = calculateAdaptiveDelay(for: event)

        // Cancel any pending refresh
        pendingTask?.cancel()

        // Store the most recent event
        pendingEvent = event

        // Record operation for learning
        recordOperation(event: event, delay: adaptiveDelay)

        // Schedule refresh with adaptive delay
        pendingTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(adaptiveDelay))

                // Check if we weren't cancelled
                guard !Task.isCancelled else { return }

                // Execute the refresh
                await executeRefresh(
                    event: event,
                    screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked,
                    optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces,
                )

            } catch {
                // Handle cancellation gracefully
            }
        }
    }

    /// Cancel pending operation
    func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingEvent = nil
    }

    /// Check if there's a pending refresh
    var hasPendingRefresh: Bool {
        pendingTask != nil && !pendingTask!.isCancelled
    }

    /// Get statistics about adaptive behavior
    func getStatistics() -> AdaptiveStatistics {
        let recentOps = operationHistory.suffix(100) // Last 100 operations

        let avgDelay = recentOps.reduce(0.0) { $0 + $1.computedDelay } / Double(max(1, recentOps.count))
        let minDelay = recentOps.map { $0.computedDelay }.min() ?? baseDelay
        let maxDelay = recentOps.map { $0.computedDelay }.max() ?? baseDelay

        let adaptiveEfficiency = calculateAdaptiveEfficiency(from: recentOps)

        return AdaptiveStatistics(
            baseDelay: baseDelay,
            averageDelay: avgDelay,
            minimumDelay: minDelay,
            maximumDelay: maxDelay,
            adaptiveEfficiency: adaptiveEfficiency,
            totalOperations: operationHistory.count,
        )
    }

    // MARK: - Private Methods

    private func calculateAdaptiveDelay(for event: RefreshSessionEvent) -> TimeInterval {
        guard config.performanceConfig.useAdaptiveDebouncing else {
            return baseDelay
        }

        // Get system metrics
        let systemMetrics = SystemLoadMonitor.shared.getCurrentMetrics()

        // Get base delay from performance config
        let configDelay = config.performanceConfig.getEffectiveDebounceDelay(
            cpuLoad: systemMetrics.currentCPUUsage,
            operationFrequency: systemMetrics.operationFrequency,
        )

        // Apply event-specific adjustments
        let eventMultiplier = getEventSpecificMultiplier(for: event)

        // Apply pattern-based adjustments
        let patternMultiplier = getPatternBasedMultiplier()

        // Apply system health adjustments
        let healthMultiplier = getHealthBasedMultiplier(systemMetrics.systemHealthScore)

        // Combine all factors
        var adaptiveDelay = configDelay * eventMultiplier * patternMultiplier * healthMultiplier

        // Apply learned optimizations
        adaptiveDelay = applyLearnedOptimizations(delay: adaptiveDelay, event: event, systemMetrics: systemMetrics)

        // Clamp to reasonable bounds
        let minDelay = config.performanceConfig.debouncingConfig.minimumDelay / 1000.0
        let maxDelay = config.performanceConfig.debouncingConfig.maximumDelay / 1000.0

        return max(minDelay, min(maxDelay, adaptiveDelay))
    }

    private func getEventSpecificMultiplier(for event: RefreshSessionEvent) -> Double {
        switch event {
            case .startup:
                return 0.5 // Faster startup
            case .ax(let notification):
                switch notification {
                    case "AXApplicationActivated":
                        return 1.2 // Slightly slower for app activation
                    case "AXWindowCreated":
                        return 0.8 // Faster for new windows
                    case "AXWindowMoved", "AXWindowResized":
                        return 1.5 // Slower for move/resize to batch operations
                    default:
                        return 1.0
                }
            case .hotkeyBinding:
                return 0.7 // Faster for manual hotkey operations
            case .menuBarButton:
                return 0.7 // Faster for manual menu operations
            case .socketServer:
                return 0.8 // Moderate speed for CLI commands
            case .onFocusChanged, .onFocusedMonitorChanged:
                return 0.8 // Faster for focus operations
            default:
                return 1.0
        }
    }

    private func getPatternBasedMultiplier() -> Double {
        let now = Date()
        let recentOps = operationHistory.filter { op in
            now.timeIntervalSince(op.timestamp) < 5.0 // Last 5 seconds
        }

        // If there have been many operations recently, increase delay
        if recentOps.count > 10 {
            return 2.0
        } else if recentOps.count > 5 {
            return 1.5
        } else if recentOps.count < 2 {
            return 0.8 // Fewer operations, can be more responsive
        }

        return 1.0
    }

    private func getHealthBasedMultiplier(_ healthScore: Double) -> Double {
        // Poor system health = longer delays
        if healthScore < 0.3 {
            return 3.0
        } else if healthScore < 0.5 {
            return 2.0
        } else if healthScore < 0.7 {
            return 1.5
        } else if healthScore > 0.9 {
            return 0.8 // Excellent health = shorter delays
        }

        return 1.0
    }

    private func applyLearnedOptimizations(
        delay: TimeInterval,
        event: RefreshSessionEvent,
        systemMetrics: SystemLoadMonitor.SystemLoadMetrics,
    ) -> TimeInterval {
        // Machine learning-inspired optimization based on historical performance

        // Find similar historical operations
        let similarOps = operationHistory.filter { op in
            isSimilarOperation(op.eventType, event) &&
                abs(op.systemLoad - systemMetrics.currentCPUUsage) < 0.2
        }.suffix(20) // Last 20 similar operations

        guard !similarOps.isEmpty else { return delay }

        // Calculate performance score for different delay ranges
        let avgHistoricalDelay = similarOps.reduce(0.0) { $0 + $1.computedDelay } / Double(similarOps.count)

        // Adjust based on historical effectiveness
        if avgHistoricalDelay > delay * 1.5 {
            // Historical delays were much higher, current system might be more efficient
            return delay * 0.9
        } else if avgHistoricalDelay < delay * 0.7 {
            // Historical delays were much lower, might need more conservative approach
            return delay * 1.1
        }

        return delay
    }

    private func isSimilarOperation(_ op1: RefreshSessionEvent, _ op2: RefreshSessionEvent) -> Bool {
        switch (op1, op2) {
            case (.startup, .startup):
                return true
            case (.hotkeyBinding, .hotkeyBinding), (.menuBarButton, .menuBarButton), (.socketServer, .socketServer):
                return true
            case (.ax(let n1), .ax(let n2)):
                return n1 == n2
            case (.globalObserver(let o1), .globalObserver(let o2)):
                return o1 == o2
            default:
                return false
        }
    }

    private func recordOperation(event: RefreshSessionEvent, delay: TimeInterval) {
        let systemLoad = SystemLoadMonitor.shared.getCurrentMetrics().currentCPUUsage

        let record = OperationRecord(
            timestamp: Date(),
            eventType: event,
            computedDelay: delay,
            systemLoad: systemLoad,
        )

        operationHistory.append(record)

        // Keep history manageable
        if operationHistory.count > 1000 {
            operationHistory.removeFirst(100)
        }

        lastOperationTime = Date()
    }

    private func executeRefresh(
        event: RefreshSessionEvent,
        screenIsDefinitelyUnlocked: Bool,
        optimisticallyPreLayoutWorkspaces: Bool,
    ) async {
        activeRefreshTask?.cancel()
        activeRefreshTask = Task { @MainActor in
            try checkCancellation()
            try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
        }

        if screenIsDefinitelyUnlocked {
            resetClosedWindowsCache()
        }
    }

    private func calculateAdaptiveEfficiency(from operations: ArraySlice<OperationRecord>) -> Double {
        guard operations.count > 10 else { return 1.0 }

        // Measure how well our adaptive delays matched actual system performance
        // This is a simplified efficiency calculation

        _ = calculateVariance(operations.map { $0.computedDelay })
        _ = calculateVariance(operations.map { $0.systemLoad })

        // Lower variance in delay when system load is stable = higher efficiency
        let stableOperations = operations.filter { abs($0.systemLoad - 0.5) < 0.2 }
        let stableDelayVariance = stableOperations.isEmpty ? 1.0 : calculateVariance(stableOperations.map { $0.computedDelay })

        // Efficiency score: lower variance under stable conditions = better
        return max(0.0, 1.0 - stableDelayVariance)
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0.0, +) / Double(values.count)
    }
}

/// Statistics about adaptive debouncing performance
struct AdaptiveStatistics: Sendable {
    let baseDelay: TimeInterval
    let averageDelay: TimeInterval
    let minimumDelay: TimeInterval
    let maximumDelay: TimeInterval
    let adaptiveEfficiency: Double // 0.0 = poor adaptation, 1.0 = excellent
    let totalOperations: Int

    var adaptiveRange: TimeInterval {
        maximumDelay - minimumDelay
    }

    var adaptiveRatio: Double {
        guard baseDelay > 0 else { return 1.0 }
        return averageDelay / baseDelay
    }
}
