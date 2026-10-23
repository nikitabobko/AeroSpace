import AppKit
import Common

@MainActor private var restackGeneration = 0
@MainActor private var isRestacking = false

/// The 'fan' accordion shows a strip of every window. A strip is visible only if nearer windows are stacked above
/// farther ones, but macOS raises only the window that gets focused. Focus jumps over several windows (wrap-around,
/// clicks, cmd-tab) break the stacking. Restore it by raising the windows that are out of order
/// - preempt: stop the restack in progress, if any. Otherwise, don't start while another restack is in progress.
///   Commands preempt. Refresh sessions don't, and every command is followed by a refresh session anyway
@MainActor
func restackFanAccordion(preempt: Bool) async throws {
    if config.accordionStyle != .fan || isUnitTest || isLeftMouseButtonDown { return }
    if !preempt && (isRestacking || isNativeFocusExpected) { return }
    restackGeneration += 1 // Stop the restack in progress, if any
    let generation = restackGeneration
    isRestacking = true
    defer {
        if generation == restackGeneration { isRestacking = false }
    }
    // Only touch the accordion of the focused window. Raising windows elsewhere could cover a focused floating window
    guard let focused = focus.windowOrNil,
          let accordion = focused.parents.last(where: { ($0 as? TilingContainer)?.layout == .accordion }) as? TilingContainer,
          let mruIndex = accordion.mostRecentChild?.ownIndex else { return }
    let raiseOrder = fanRaiseOrder(
        children: accordion.children.map { $0.allLeafWindowsRecursive.map(\.windowId) },
        mruIndex: mruIndex,
        stackingOrder: getWindowStackingOrder(),
    )
    let mruWindowIds = accordion.children[mruIndex].allLeafWindowsRecursive.map(\.windowId)
    // Raising a window can make macOS focus it (e.g. by activating its app). Ignore that until the end of the restack.
    // If a stopped restack was waiting for another window, wait for the focused one instead
    let raisesOthers = raiseOrder.contains { !mruWindowIds.contains($0) }
    if raisesOthers || isNativeFocusExpected { expectNativeFocus(focused) }
    for windowId in raiseOrder {
        if generation != restackGeneration { return } // A newer restack took over
        guard let window = Window.get(byId: windowId) as? MacWindow else { continue }
        // Raise sequentially. Windows of different apps are raised on different threads
        try await window.raise(.cancellable)
        // The raise might have changed the native focus of the app. Make the next nativeFocus fully focus the window
        window.macApp.lastNativeFocusedWindowId = nil
    }
    if raisesOthers { focused.nativeFocus() } // Take the native focus back from the raised windows
}

/// Returns the windows to raise, in the order of raising, so that the windows of the most recent child end up above all
/// the other windows, and on each side of it, the windows of nearer children end up above the windows of farther ones.
/// - children: window ids of every child
/// - stackingOrder: positions of the on-screen windows. 0 is the frontmost. Other windows are ignored
func fanRaiseOrder(children: [[UInt32]], mruIndex: Int, stackingOrder: [UInt32: Int]) -> [UInt32] {
    guard children.indices.contains(mruIndex) else { return [] }
    // Raising the windows of a child from the back to the front keeps their relative order
    func backToFront(_ windowIds: [UInt32]) -> [(id: UInt32, pos: Int)] {
        windowIds.compactMap { id in stackingOrder[id].map { (id: id, pos: $0) } }.sorted { $0.pos > $1.pos }
    }
    var result: [UInt32] = []
    var frontmostSidePos = Int.max
    // Children on each side of the most recent one, from the nearest to the farthest
    for side in [Array(children[..<mruIndex].reversed()), Array(children[(mruIndex + 1)...])] {
        let side = side.map(backToFront).filter { !$0.isEmpty }
        guard let farthest = side.indices.last else { continue }
        frontmostSidePos = min(frontmostSidePos, side.map { $0.last.orDie().pos }.min().orDie())
        // The farthest children that are already stacked in order stay. The rest is raised, starting from the farthest
        var firstInOrder = farthest
        while firstInOrder > 0 && side[firstInOrder - 1].first.orDie().pos < side[firstInOrder].last.orDie().pos {
            firstInOrder -= 1
        }
        result += side[..<firstInOrder].reversed().flatMap { $0.map(\.id) }
    }
    let mru = backToFront(children[mruIndex])
    if !result.isEmpty || (mru.first?.pos ?? -1) > frontmostSidePos {
        result += mru.map(\.id)
    }
    return result
}

/// Window ids of the on-screen windows mapped to their position in the stacking order. 0 is the frontmost
private func getWindowStackingOrder() -> [UInt32: Int] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cfArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return [:] }
    var result: [UInt32: Int] = [:]
    for (pos, elem) in cfArray.enumerated() {
        let dict = elem as NSDictionary
        guard let _windowId = dict[kCGWindowNumber] else { continue }
        result[((_windowId as! CFNumber) as NSNumber).uint32Value] = pos
    }
    return result
}
