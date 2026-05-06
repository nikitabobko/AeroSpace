import AppKit
import Foundation

enum TabHeaderMetrics {
    static let height = CGFloat(28)
    static let horizontalPadding = CGFloat(6)
    static let verticalPadding = CGFloat(4)
    static let itemSpacing = CGFloat(6)
    static let cornerRadius = CGFloat(7)
    static let minTabWidth = CGFloat(72)
    static let titleHorizontalInset = CGFloat(10)
    static let closeButtonSize = CGFloat(12)
    static let closeButtonTrailingInset = CGFloat(9)
    static let closeButtonLeadingSpacing = CGFloat(6)
}

struct TabHeaderItem: Identifiable {
    let id: String
    let targetWindow: Window
    let title: String
    let frame: Rect
    let titleFrame: Rect
    let closeButtonFrame: Rect
    let isActive: Bool
}

struct TabHeaderSnapshot: Identifiable {
    let id: ObjectIdentifier
    let headerFrame: Rect
    let items: [TabHeaderItem]
}

@MainActor
final class LayoutContext {
    let workspace: Workspace
    let resolvedGaps: ResolvedGaps
    var tabHeaderSnapshots: [TabHeaderSnapshot] = []

    init(_ workspace: Workspace) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    }
}

@MainActor
final class TabHeaderInteractionState {
    static let shared = TabHeaderInteractionState()

    private var latestInteractionAt: Date = .distantPast
    private var hasPendingGlobalMouseUpSuppression = false
    private let suppressionInterval: TimeInterval = 0.35

    private init() {}

    func markInteraction() {
        latestInteractionAt = .now
        hasPendingGlobalMouseUpSuppression = true
    }

    func consumePendingGlobalMouseRefreshSuppression(now: Date = .now) -> Bool {
        guard hasPendingGlobalMouseUpSuppression else { return false }
        hasPendingGlobalMouseUpSuppression = false
        return latestInteractionAt.distance(to: now) <= suppressionInterval
    }
}

@MainActor
final class TabHeaderTitleCache {
    static let shared = TabHeaderTitleCache()

    private struct Entry {
        let title: String
        let updatedAt: Date
    }

    private var titles: [UInt32: Entry] = [:]
    private let ttl: TimeInterval = 1

    private init() {}

    func title(for window: Window, now: Date = .now) async throws -> String {
        let shouldRefresh = focus.windowOrNil == window
        if let cached = titles[window.windowId],
           !shouldRefresh,
           cached.updatedAt.distance(to: now) <= ttl
        {
            return cached.title
        }
        let rawTitle = try await window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = if !rawTitle.isEmpty {
            rawTitle
        } else if let appName = window.app.name?.trimmingCharacters(in: .whitespacesAndNewlines), !appName.isEmpty {
            appName
        } else {
            "Window \(window.windowId)"
        }
        titles[window.windowId] = Entry(title: resolved, updatedAt: now)
        return resolved
    }

    func cachedTitle(for windowId: UInt32) -> String? {
        titles[windowId]?.title
    }

    func invalidate(windowId: UInt32) {
        titles.removeValue(forKey: windowId)
    }

    func invalidateAll() {
        titles = [:]
    }
}

extension TreeNode {
    @MainActor
    func tabHeaderTargetWindow() -> Window? {
        switch nodeCases {
            case .window(let window):
                return window
            case .tilingContainer:
                return mostRecentWindowRecursive ?? anyLeafWindowRecursive
            case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return nil
        }
    }

    @MainActor
    func tabHeaderTitle() async throws -> String? {
        guard let targetWindow = tabHeaderTargetWindow() else { return nil }
        return try await TabHeaderTitleCache.shared.title(for: targetWindow)
    }
}
