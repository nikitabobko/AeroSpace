import AppKit
import Common

@MainActor
final class RefreshDebouncer {
    private var pendingTask: Task<Void, Never>?
    private var pendingEvent: RefreshSessionEvent?
    private let delay: TimeInterval
    private let adaptiveDebouncer: AdaptiveDebouncer

    init(delay: TimeInterval = 0.05) { // 50ms default delay
        self.delay = delay
        self.adaptiveDebouncer = AdaptiveDebouncer(baseDelay: delay)
    }

    func debounce(
        event: RefreshSessionEvent,
        screenIsDefinitelyUnlocked: Bool,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) {
        // Use adaptive debouncing if enabled, otherwise use fixed delay
        if config.performanceConfig.useAdaptiveDebouncing {
            adaptiveDebouncer.debounce(
                event: event,
                screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked,
                optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces,
            )
        } else {
            // Original fixed-delay implementation
            debounceWithFixedDelay(
                event: event,
                screenIsDefinitelyUnlocked: screenIsDefinitelyUnlocked,
                optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces,
            )
        }
    }

    private func debounceWithFixedDelay(
        event: RefreshSessionEvent,
        screenIsDefinitelyUnlocked: Bool,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) {
        // Cancel any pending refresh
        pendingTask?.cancel()

        // Store the most recent event
        pendingEvent = event

        // Schedule a new refresh after the delay
        pendingTask = Task { @MainActor in
            // Wait for the debounce delay
            try? await Task.sleep(for: .seconds(delay))

            // Check if we weren't cancelled
            guard !Task.isCancelled else { return }

            // Execute the refresh
            activeRefreshTask?.cancel()
            activeRefreshTask = Task { @MainActor in
                try checkCancellation()
                try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
            }

            if screenIsDefinitelyUnlocked {
                resetClosedWindowsCache()
            }
        }
    }

    func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingEvent = nil
        adaptiveDebouncer.cancelPending()
    }

    var hasPendingRefresh: Bool {
        if config.performanceConfig.useAdaptiveDebouncing {
            return adaptiveDebouncer.hasPendingRefresh
        } else {
            return pendingTask != nil && !pendingTask!.isCancelled
        }
    }

    /// Get statistics about debouncing performance
    func getStatistics() -> DebouncingStatistics {
        if config.performanceConfig.useAdaptiveDebouncing {
            let adaptiveStats = adaptiveDebouncer.getStatistics()
            return DebouncingStatistics(
                isAdaptive: true,
                baseDelay: adaptiveStats.baseDelay,
                averageDelay: adaptiveStats.averageDelay,
                efficiency: adaptiveStats.adaptiveEfficiency,
                totalOperations: adaptiveStats.totalOperations,
            )
        } else {
            return DebouncingStatistics(
                isAdaptive: false,
                baseDelay: delay,
                averageDelay: delay,
                efficiency: 1.0,
                totalOperations: 0,
            )
        }
    }
}

struct DebouncingStatistics: Sendable {
    let isAdaptive: Bool
    let baseDelay: TimeInterval
    let averageDelay: TimeInterval
    let efficiency: Double
    let totalOperations: Int
}
