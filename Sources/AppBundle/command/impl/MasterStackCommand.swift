import AppKit
import Common

struct MasterStackCommand: Command {
    let args: MasterStackCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace
        let root = workspace.rootTilingContainer

        let allWindows = root.allLeafWindowsRecursive
        guard allWindows.count >= 2 else { return true }

        let master: Window
        if args.cycle {
            // Use stable window ID order so cycling visits all windows
            let sortedById = allWindows.sorted { $0.windowId < $1.windowId }
            // Current master is the first leaf in the tree (DFS)
            guard let currentMaster = allWindows.first else { return true }
            let currentIndex = sortedById.firstIndex(of: currentMaster) ?? 0
            let nextIndex = (currentIndex + 1) % sortedById.count
            master = sortedById[nextIndex]
        } else {
            guard let focusedWindow = target.windowOrNil else {
                return io.err(noWindowIsFocused)
            }
            master = focusedWindow
        }

        // Step 1: Flatten all windows to root (same as flatten-workspace-tree)
        for window in allWindows {
            window.bind(to: root, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        root.changeOrientation(.h)

        // Step 2: Collect non-master windows
        var others: [Window] = []
        for window in root.allLeafWindowsRecursive where window !== master {
            others.append(window)
        }

        // Step 3: Move master to index 0 with weight 7
        master.bind(to: root, adaptiveWeight: 7, index: 0)

        // Step 4: Create stack container and build spiral
        if others.count == 1 {
            others[0].bind(to: root, adaptiveWeight: 3, index: 1)
        } else {
            let stackContainer = TilingContainer(
                parent: root,
                adaptiveWeight: 3,
                .v,
                .tiles,
                index: 1,
            )
            buildSpiral(windows: others, parent: stackContainer, startOrientation: .h)
        }

        // Focus the master window
        if args.cycle {
            _ = master.focusWindow()
        }

        return true
    }

    @MainActor private func buildSpiral(windows: [Window], parent: TilingContainer, startOrientation: Orientation) {
        if windows.count == 1 {
            windows[0].bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        } else if windows.count == 2 {
            windows[0].bind(to: parent, adaptiveWeight: 1, index: 0)
            windows[1].bind(to: parent, adaptiveWeight: 1, index: 1)
        } else {
            windows[0].bind(to: parent, adaptiveWeight: 1, index: 0)
            let sub = TilingContainer(
                parent: parent,
                adaptiveWeight: 1,
                startOrientation,
                .tiles,
                index: 1,
            )
            buildSpiral(windows: Array(windows.dropFirst()), parent: sub, startOrientation: startOrientation.opposite)
        }
    }
}
