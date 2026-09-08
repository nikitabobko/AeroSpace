import AppKit

/// AXWindows contains only the selected tab. Inactive Finder tabs can retain
/// valid AX window IDs, so ID validity alone must not keep them in the layout.
struct FinderTabSnapshot {
    let members: Set<UInt>
    let frame: CGRect?

    init(members: Set<UInt>, frame: CGRect?) {
        self.members = members
        self.frame = frame
    }

    init(_ window: AXUIElement) {
        let groups = (window.get(Ax.childrenAttr) ?? []).filter { $0.get(Ax.roleAttr) == kAXTabGroupRole }
        members = Set(groups.flatMap { $0.get(Ax.childrenAttr) ?? [] }.map { CFHash($0) })
        if let origin = window.get(Ax.topLeftCornerAttr), let size = window.get(Ax.sizeAttr) {
            frame = CGRect(origin: origin, size: size)
        } else {
            frame = nil
        }
    }

    func matches(_ previous: FinderTabSnapshot?) -> Bool {
        guard let previous else { return false }
        if !members.isDisjoint(with: previous.members) { return true }
        // Some Finder versions recreate the tab controls. Only transfer a slot
        // when the outgoing/incoming native window has the same frame and at
        // least one side has a tab bar (including opening the first extra tab).
        return (!members.isEmpty || !previous.members.isEmpty) &&
            frame != nil && frame == previous.frame
    }
}
