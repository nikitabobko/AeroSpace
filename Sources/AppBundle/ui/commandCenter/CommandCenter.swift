import AppKit
import Common

/// The command center: a full-screen overview of all workspaces on all monitors
@MainActor
final class CommandCenter {
    static let shared = CommandCenter()
    private init() {}

    private var windows: [CommandCenterWindow] = []
    private(set) var snapshot: CommandCenterSnapshot? = nil
    private(set) var titles: [OpaqueWindowId: String] = [:]
    private(set) var drag: Drag? = nil
    /// Name of the workspace under the mouse
    private(set) var hover: String? = nil
    private(set) var palette = CommandCenterPalette(config: CommandCenterConfig(), jankyBorders: nil)
    private var prevFocus: (windowId: OpaqueWindowId?, workspaceName: String)? = nil
    private var titlesTask: Task<(), Never>? = nil
    private var keyMonitor: Any? = nil

    struct Drag {
        let source: DragSource
        /// Top-left origin. The same coordinate space as `Rect`
        var point: CGPoint
        var target: DropTarget?
    }

    var isOpen: Bool { !windows.isEmpty }

    func open(_ snapshot: CommandCenterSnapshot) {
        if isOpen { return }
        let focus = globalFocus
        prevFocus = (focus.windowOrNil?.windowId, focus.workspace.name)
        self.snapshot = snapshot
        titles = [:]
        hover = nil
        let colors = config.commandCenter
        palette = CommandCenterPalette(config: colors, jankyBorders: colors.jankyBorders ? JankyBorders.detect() : nil)
        for monitor in snapshot.monitors {
            let window = CommandCenterWindow(monitor: monitor)
            windows.append(window)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                Task.startUnstructured { @MainActor in await CommandCenter.shared.close(restoreFocus: true) }
                return nil
            }
            return event
        }
        fetchTitles()
    }

    /// - Parameter restoreFocus: Restore the focus to where it was when the command center was opened
    func close(restoreFocus: Bool) async {
        if !isOpen { return }
        titlesTask?.cancel()
        titlesTask = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows {
            window.close()
        }
        windows = []
        drag = nil
        hover = nil
        snapshot = nil
        let prevFocus = prevFocus
        self.prevFocus = nil
        guard restoreFocus, let prevFocus else { return }
        await inSession {
            if let windowId = prevFocus.windowId, let window = Window.get(byId: windowId), window.focusWindow() {
                window.nativeFocus()
            } else {
                _ = Workspace.get(byName: prevFocus.workspaceName).focusWorkspace()
                NSApp.deactivate()
            }
        }
    }

    /// Reflects the changes the command center made: every window gets the layout of the fresh snapshot of its monitor
    private func refresh() async {
        guard isOpen, let snapshot = try? await CommandCenterSnapshot.capture(.nonCancellable) else { return }
        self.snapshot = snapshot
        for window in windows {
            if let monitor = snapshot.monitors.first(where: { $0.rect.topLeftCorner == window.monitor.rect.topLeftCorner }) {
                window.update(monitor)
            }
        }
        // The session that ran the gesture may have synced the focus to macOS, which activates another app. Take the key
        // status back, otherwise Escape stops working
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        redraw()
        fetchTitles()
    }

    private func redraw() {
        for window in windows {
            window.contentView?.needsDisplay = true
        }
    }

    /// Window titles are fetched after the command center is shown, because they require an AX request per window
    private func fetchTitles() {
        titlesTask?.cancel()
        titlesTask = Task.startUnstructured { @MainActor [weak self] in
            guard let snapshot = self?.snapshot else { return }
            for windowSnapshot in snapshot.allWindows where self?.titles[windowSnapshot.windowId] == nil {
                guard let window = Window.get(byId: windowSnapshot.windowId) else { continue }
                let title = try? await window.getTitle(.cancellable) // One unresponsive app must not hide the other titles
                guard let self, !Task.isCancelled else { return }
                if let title { self.titles[windowSnapshot.windowId] = title }
            }
            self?.redraw()
        }
    }

    // MARK: - Gestures

    func setHover(_ workspace: String?) {
        if hover == workspace { return }
        hover = workspace
        redraw()
    }

    func clickWorkspace(_ name: String) async {
        await close(restoreFocus: false)
        await run(["workspace", "--", name])
    }

    func clickWindow(_ window: WindowSnapshot) async {
        await close(restoreFocus: false)
        await run(["focus", "--window-id", window.windowId.description])
    }

    func beginDrag(_ source: DragSource, at point: CGPoint) {
        drag = Drag(source: source, point: point, target: nil)
        redraw()
    }

    func updateDrag(to point: CGPoint) {
        guard var drag else { return }
        drag.point = point
        drag.target = dropTarget(at: point, dragging: drag.source)
        self.drag = drag
        redraw()
    }

    func endDrag() async {
        guard let drag else { return }
        self.drag = nil
        redraw()
        guard let target = drag.target else { return }
        switch (drag.source, target) {
            case (.workspace(let source), .swap(let target)):
                await run(["swap-workspaces", "--", source, target])
            case (.workspace, _), (.window, .swap):
                return // Impossible: DropTarget pairs sources with their targets
            case (.window(let source), .workspace(let name)):
                if name == source.workspace && source.kind == .tiling { return }
                await run(["move-node-to-workspace", "--window-id", source.windowId.description, "--", name])
            case (.window(let source), .before(let target)):
                guard let workspace = target.workspace, let parent = target.parentPath, let index = target.indexInParent else { return }
                await run(["move-node-to-container", "--window-id", source.windowId.description, "--", workspace, parent.description, String(index)])
            case (.window(let source), .after(let target)):
                guard let workspace = target.workspace, let parent = target.parentPath, let index = target.indexInParent else { return }
                await run(["move-node-to-container", "--window-id", source.windowId.description, "--", workspace, parent.description, String(index + 1)])
            case (.window(let source), .join(let target)):
                guard let workspace = target.workspace, let parent = target.parentPath, let index = target.indexInParent, let orientation = target.parentOrientation else { return }
                await run([
                    ["move-node-to-container", "--window-id", source.windowId.description, "--", workspace, parent.description, String(index + 1)],
                    ["join-with", "--window-id", source.windowId.description, orientation == .h ? "left" : "up"],
                ])
        }
        await refresh()
    }

    private func dropTarget(at point: CGPoint, dragging source: DragSource) -> DropTarget? {
        guard let window = windows.first(where: { $0.monitor.rect.contains(point) }) else { return nil }
        let local = CGPoint(x: point.x - window.monitor.rect.topLeftX, y: point.y - window.monitor.rect.topLeftY)
        return DropTarget(window.layout, at: local, dragging: source)
    }

    private func run(_ commands: [[String]]) async {
        await inSession {
            for args in commands {
                guard let command = parseCommand(args).cmdOrNil else { return }
                let result = await command.run(.defaultEnv, .emptyStdin)
                if result.exitCode.rawValue != 0 { return }
            }
        }
    }

    /// Gestures come from AppKit events (outside of any session), while the toggle command runs inside of a session.
    /// Sessions must not be nested
    private func inSession(_ body: @MainActor () async -> ()) async {
        if refreshSessionEvent != nil {
            await body()
        } else if let guard_ = RunSessionGuard.isServerEnabled {
            _ = try? await runLightSession(.commandCenter, guard_) { await body() }
        }
    }

    private func run(_ args: [String]) async {
        await run([args])
    }
}

/// What the command center draws with: the config colors, with the colors and the width of JankyBorders on top when it runs
struct CommandCenterPalette {
    let config: CommandCenterConfig
    let jankyBorders: JankyBorders?

    var backgroundColor: ArgbColor { config.backgroundColor }
    var workspaceColor: ArgbColor { config.workspaceColor }
    var hoverColor: ArgbColor { config.hoverColor }
    var windowColor: ArgbColor { config.windowColor }
    var textColor: ArgbColor { config.textColor }
    /// Focused workspace and window, drop target
    var activeColor: ArgbColor { jankyBorders?.activeColor ?? config.activeColor }
    /// Workspaces visible on other monitors
    var visibleColor: ArgbColor { jankyBorders?.inactiveColor ?? config.visibleColor }
    /// Everything else
    var inactiveColor: ArgbColor { config.inactiveColor }
    /// The ring around the focused tile
    var ringWidth: CGFloat { jankyBorders?.width ?? CommandCenterLayout.defaultRingWidth }
}
