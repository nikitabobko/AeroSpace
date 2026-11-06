import AppKit
import Common

/// Everything the command center draws. Captured once when the command center opens, and after every change it makes
struct CommandCenterSnapshot {
    let monitors: [MonitorSnapshot]

    @MainActor
    static func capture(_ cm: CancellationMode) async throws -> CommandCenterSnapshot {
        let focus = globalFocus
        // Minimized windows belong to no workspace and no monitor. The shelf shows them on the monitor the user looks at
        let shelfMonitor = focus.workspace.workspaceMonitorInfo.rect.topLeftCorner
        let minimized = macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self).filter { $0.lifeStatus.isInhabited }
            .map { WindowSnapshot($0, workspace: nil, frame: nil, path: nil, kind: .macosMinimized, focus: focus) }
        var monitors: [MonitorSnapshot] = []
        for monitor in globalSortedMonitorInfos {
            var workspaces: [WorkspaceSnapshot] = []
            for workspace in Workspace.all where workspace.workspaceMonitorInfo.rect.topLeftCorner == monitor.rect.topLeftCorner {
                workspaces.append(try await WorkspaceSnapshot.capture(workspace, focus: focus, cm))
            }
            let shelf = monitor.rect.topLeftCorner == shelfMonitor ? minimized : []
            monitors.append(MonitorSnapshot(rect: monitor.rect, workspaces: workspaces, shelf: shelf))
        }
        return CommandCenterSnapshot(monitors: monitors)
    }

    var allWindows: [WindowSnapshot] { monitors.flatMap { $0.workspaces.flatMap { $0.windows + $0.chips } + $0.shelf } }
}

struct MonitorSnapshot {
    let rect: Rect
    let workspaces: [WorkspaceSnapshot]
    /// Minimized windows, drawn as a shelf at the bottom of the monitor
    let shelf: [WindowSnapshot]
}

struct WorkspaceSnapshot {
    let name: String
    let isFocused: Bool
    let isVisible: Bool
    /// Windows with a place in the layout. Tiling windows come first, floating windows come last (so that floating windows are
    /// drawn on top)
    let windows: [WindowSnapshot]
    /// Windows that belong to the workspace but have no place in its layout: macOS fullscreen windows and windows of hidden
    /// apps. Drawn as chips
    let chips: [WindowSnapshot]

    @MainActor
    static func capture(_ workspace: Workspace, focus: LiveFocus, _ cm: CancellationMode) async throws -> WorkspaceSnapshot {
        let measurement = try await workspace.measureLayout()
        var windows: [WindowSnapshot] = []
        workspace.rootTilingContainer.visitWindows(path: [], measurement: measurement, map: { $0 }) { window, path, frame in
            windows.append(WindowSnapshot(window, workspace: workspace.name, frame: frame, path: path, kind: .tiling, focus: focus))
        }
        for window in workspace.floatingWindows where window.lifeStatus.isInhabited {
            let frame = if let rect = window.unhiddenFloatingRect { rect } else { try await window.getAxRect(cm) }
            if let frame {
                windows.append(WindowSnapshot(window, workspace: workspace.name, frame: frame, path: nil, kind: .floating, focus: focus))
            }
        }
        var chips: [WindowSnapshot] = []
        for window in workspace.macOsNativeFullscreenWindowsContainer.children.filterIsInstance(of: Window.self) where window.lifeStatus.isInhabited {
            chips.append(WindowSnapshot(window, workspace: workspace.name, frame: nil, path: nil, kind: .macosFullscreen, focus: focus))
        }
        for window in workspace.macOsNativeHiddenAppsWindowsContainer.children.filterIsInstance(of: Window.self) where window.lifeStatus.isInhabited {
            chips.append(WindowSnapshot(window, workspace: workspace.name, frame: nil, path: nil, kind: .macosHiddenApp, focus: focus))
        }
        return WorkspaceSnapshot(name: workspace.name, isFocused: focus.workspace == workspace, isVisible: workspace.isVisible, windows: windows, chips: chips)
    }
}

struct WindowSnapshot: Equatable {
    enum Kind: Equatable {
        case tiling
        case floating
        case macosFullscreen
        case macosHiddenApp
        case macosMinimized
    }

    let windowId: OpaqueWindowId
    /// nil for minimized windows
    let workspace: String?
    let appName: String
    let icon: NSImage?
    let isFocused: Bool
    /// In the coordinates of the monitor layout (as if the workspace was visible). nil for windows without a place in the layout
    let frame: Rect?
    /// nil for everything but tiling windows
    let path: ContainerPath?
    let parentOrientation: Orientation?
    let kind: Kind

    @MainActor
    init(_ window: Window, workspace: String?, frame: Rect?, path: ContainerPath?, kind: Kind, focus: LiveFocus) {
        self.windowId = window.windowId
        self.workspace = workspace
        self.appName = window.app.name ?? ""
        self.icon = (window.app as? MacApp)?.nsApp.icon
        self.isFocused = focus.windowOrNil == window
        self.frame = frame
        self.path = path
        self.parentOrientation = (window.parent as? TilingContainer)?.orientation
        self.kind = kind
    }

    /// Tiling and floating windows take part in the layout. The rest is drawn as chips
    var isInLayout: Bool { kind == .tiling || kind == .floating }
    var parentPath: ContainerPath? { path.map { ContainerPath($0.indices.dropLast()) } }
    var indexInParent: Int? { path?.indices.last }

    static func == (lhs: WindowSnapshot, rhs: WindowSnapshot) -> Bool { lhs.windowId == rhs.windowId }
}

extension TilingContainer {
    /// Visits every window with the rectangle it takes in the overview.
    ///
    /// Tiles keep their measured rectangles. Accordion children share one rectangle on the desktop, which would draw them
    /// on top of each other, so the overview spreads them out evenly along the container orientation instead.
    /// `map` carries the accumulated transformation from measured to overview rectangles down the tree
    fileprivate func visitWindows(path: [Int], measurement: LayoutMeasurement, map: @escaping (Rect) -> Rect, _ visit: (Window, ContainerPath, Rect) -> ()) {
        // Inhabited children only: the same children (and the same paths) dump-workspace-tree and move-node-to-container use
        for (index, child) in inhabitedChildren.enumerated() {
            var childMap = map
            if layout == .accordion, let bounds = measurement.rect(of: self), let childBounds = measurement.rect(of: child) {
                let mapped = map(bounds)
                let count = CGFloat(inhabitedChildren.count)
                let slice = switch orientation {
                    case .h: Rect(topLeftX: mapped.topLeftX + mapped.width / count * CGFloat(index), topLeftY: mapped.topLeftY, width: mapped.width / count, height: mapped.height)
                    case .v: Rect(topLeftX: mapped.topLeftX, topLeftY: mapped.topLeftY + mapped.height / count * CGFloat(index), width: mapped.width, height: mapped.height / count)
                }
                let scaleX = slice.width / childBounds.width
                let scaleY = slice.height / childBounds.height
                childMap = { rect in
                    Rect(
                        topLeftX: slice.topLeftX + (rect.topLeftX - childBounds.topLeftX) * scaleX,
                        topLeftY: slice.topLeftY + (rect.topLeftY - childBounds.topLeftY) * scaleY,
                        width: rect.width * scaleX,
                        height: rect.height * scaleY,
                    )
                }
            }
            switch child.tilingTreeNodeCasesOrDie() {
                case .window(let window):
                    if let frame = measurement.rect(of: window) { visit(window, ContainerPath(path + [index]), childMap(frame)) }
                case .tilingContainer(let container):
                    container.visitWindows(path: path + [index], measurement: measurement, map: childMap, visit)
            }
        }
    }
}
