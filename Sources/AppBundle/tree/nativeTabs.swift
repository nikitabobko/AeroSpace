import AppKit
import Common

// AXWindows lists only the frontmost native tab. The tab bar (AXTabGroup) of a tab group is one element that moves to
// the frontmost tab, and it still reports its host when AXWindows doesn't list the host, such as on another Space
struct NativeTab<TabBar: Hashable>: Equatable {
    var isListed: Bool
    var tabBar: TabBar? = nil
    var tabCount = 0
}

protocol NativeTabsAx {
    associatedtype TabBar: Hashable
    func isStandardWindow(_ windowId: UInt32) throws -> Bool
    func tabBar(ofWindow windowId: UInt32) throws -> TabBar?
    func host(of tabBar: TabBar) throws -> UInt32?
    func tabCount(of tabBar: TabBar) throws -> Int
    func isAlive(_ windowId: UInt32) throws -> Bool
    func orderedInWindowIds() throws -> Set<UInt32>?
}

struct NativeTabsObservation<TabBar: Hashable> {
    var windows: [UInt32: NativeTab<TabBar>]
    var takeovers: [(from: UInt32, to: UInt32)]

    func commit<Window>(
        to registeredWindows: inout [UInt32: Window],
        _ nativeTab: WritableKeyPath<Window, NativeTab<TabBar>?>,
    ) -> [UInt32: WindowLifeStatus] {
        registeredWindows = registeredWindows.filter { windows[$0.key] != nil }
        for (id, window) in windows {
            registeredWindows[id]?[keyPath: nativeTab] = window
        }
        return windows.mapValues { $0.isListed ? .alive : .invisible }
    }
}

func observeNativeTabs<Ax: NativeTabsAx>(
    previous: [UInt32: NativeTab<Ax.TabBar>],
    aliveWindowIds: Set<UInt32>,
    listedWindowIds: Set<UInt32>?,
    _ ax: Ax,
) throws -> NativeTabsObservation<Ax.TabBar> {
    // Xcode answers AXWindows with kAXErrorCannotComplete while it creates a tab
    guard let listedWindowIds else {
        return NativeTabsObservation(windows: previous.filter { aliveWindowIds.contains($0.key) }, takeovers: [])
    }
    // AXFocusedWindow can report a tab before AXWindows lists it
    var windows = aliveWindowIds.filter { previous[$0] != nil || listedWindowIds.contains($0) }.associate { id in
        var window = previous[id] ?? NativeTab(isListed: false)
        window.isListed = listedWindowIds.contains(id)
        return window
    }
    var takeovers: [(from: UInt32, to: UInt32)] = []
    var backgroundTabs: Set<UInt32> = []
    var hasTabBarGainedTabs = false

    var goneTabBars: [(host: UInt32, tabBar: Ax.TabBar, isHostClosed: Bool)] = []
    for (id, window) in previous {
        guard let tabBar = window.tabBar else { continue }
        let host = try ax.host(of: tabBar)
        if let host, host == id || windows[host]?.isListed == true {
            let tabCount = try ax.tabCount(of: tabBar)
            if tabCount > window.tabCount { hasTabBarGainedTabs = true }
            if host != id {
                takeovers.append((from: id, to: host))
                if windows[id]?.tabBar == tabBar { windows[id]?.forgetTabBar() }
                if windows[id]?.isListed == false { backgroundTabs.insert(id) }
            }
            windows[host]?.tabBar = tabBar
            windows[host]?.tabCount = tabCount
        } else if host == nil, try ax.tabCount(of: tabBar) < 2 {
            // Finder detaches the tab bar from its host for a moment during a tab switch, and the tab bar keeps its tabs
            let isHostClosed = try windows[id] == nil || !ax.isAlive(id)
            if windows[id]?.isListed == true, windows[id]?.tabBar == tabBar, !isHostClosed { windows[id]?.forgetTabBar() }
            goneTabBars.append((host: id, tabBar: tabBar, isHostClosed: isHostClosed))
        }
    }

    // Only the windows that may have just got a tab bar are checked, AXChildren is expensive
    let departedWindowIds = previous.keys.filter { previous[$0]?.isListed == true && !listedWindowIds.contains($0) }
    var knownTabBars = windows.values.compactMap(\.tabBar).toSet()
    let previousTabBars = previous.values.compactMap(\.tabBar).toSet()
    var hostsOfNewTabBars: [UInt32] = []
    for id in listedWindowIds where windows[id]?.tabBar == nil && (previous[id]?.isListed != true || !departedWindowIds.isEmpty) {
        guard try ax.isStandardWindow(id), let tabBar = try ax.tabBar(ofWindow: id), !knownTabBars.contains(tabBar) else { continue }
        let tabCount = try ax.tabCount(of: tabBar)
        windows[id]?.tabBar = tabBar
        windows[id]?.tabCount = tabCount
        knownTabBars.insert(tabBar)
        if !previousTabBars.contains(tabBar) {
            hostsOfNewTabBars.append(id)
            hasTabBarGainedTabs = true
        }
    }

    let goneTabBarHosts = goneTabBars.filter { !$0.isHostClosed }.map(\.host).toSet()
    func mayHaveJoinedTabGroup(_ id: UInt32) -> Bool {
        windows[id]?.isListed == false && !backgroundTabs.contains(id) && (windows[id]?.tabBar == nil || goneTabBarHosts.contains(id))
    }
    // Restoring a minimized tab group unlists its background tabs without tabCount increasing
    let isTabGroupListed = windows.values.contains { $0.isListed && $0.tabBar != nil }
    // Xcode can unlist a window a refresh before AXWindows lists its new tab
    let earlierDepartedIds = hasTabBarGainedTabs ? previous.keys.filter { previous[$0]?.isListed == false } : []
    let candidateIds = (hasTabBarGainedTabs || isTabGroupListed ? departedWindowIds : []).filter(mayHaveJoinedTabGroup)
        + earlierDepartedIds.filter(mayHaveJoinedTabGroup)
    // Background tabs are ordered out, unlike unlisted windows on other Spaces or next to native fullscreen
    if !candidateIds.isEmpty, let orderedInWindowIds = try ax.orderedInWindowIds() {
        let otherTabIds = candidateIds.filter { !orderedInWindowIds.contains($0) }
        backgroundTabs.formUnion(otherTabIds)
        if let frontmostTabId = hostsOfNewTabBars.singleOrNil(), previous[frontmostTabId] == nil,
           let otherTabId = otherTabIds.singleOrNil()
        {
            takeovers.append((from: otherTabId, to: frontmostTabId))
        }
    }

    let formerHost = goneTabBars.filter { host, tabBar, isHostClosed in
        guard let window = windows[host], !isHostClosed else { return true }
        return backgroundTabs.contains(host) || window.tabBar != nil && window.tabBar != tabBar
    }.singleOrNil()
    let lastTabId = listedWindowIds.filter { previous[$0] == nil && windows[$0]?.tabBar == nil }.singleOrNil()
    if let formerHost, let lastTabId {
        takeovers.append((from: formerHost.host, to: lastTabId))
        if formerHost.isHostClosed { windows[formerHost.host] = nil }
    }

    for id in backgroundTabs {
        windows[id] = nil
    }
    return NativeTabsObservation(windows: windows, takeovers: takeovers)
}

extension NativeTab {
    fileprivate mutating func forgetTabBar() {
        tabBar = nil
        tabCount = 0
    }
}

func takeOverTabGroupNodes<Node: Hashable>(
    _ takeovers: [(tabGroupNode: Node, frontmostTabId: UInt32)],
    _ mapping: inout BiDictionary<Node, UInt32>,
    focusedNode: Node?,
) -> Node? {
    let focusedWindowId = focusedNode.flatMap { mapping.forward[$0] }
    for (tabGroupNode, frontmostTabId) in takeovers {
        mapping.put(tabGroupNode, frontmostTabId)
    }
    guard let focusedWindowId, let newNode = mapping.backward[focusedWindowId], newNode != focusedNode else { return nil }
    return newNode
}
