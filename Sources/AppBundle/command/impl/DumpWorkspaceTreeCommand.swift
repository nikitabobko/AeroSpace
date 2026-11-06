import AppKit
import Common
import Foundation

struct DumpWorkspaceTreeCommand: Command {
    let args: DumpWorkspaceTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let focus = globalFocus
        var workspaces: Set<Workspace> = args.workspaces.isEmpty
            ? Workspace.all.toSet()
            : args.workspaces
                .flatMap { filter in
                    switch filter {
                        case .focused: [focus.workspace]
                        case .visible: Workspace.all.filter(\.isVisible)
                        case .name(let name): [Workspace.get(byName: name.raw)]
                    }
                }
                .toSet()
        if !args.monitors.isEmpty {
            let monitors: Set<CGPoint> = args.monitors.resolveMonitors(io)
            if monitors.isEmpty { return .fail }
            workspaces = workspaces.filter { monitors.contains($0.workspaceMonitorInfo.rect.topLeftCorner) }
        }

        var dumps: [Json] = []
        for workspace in workspaces.sorted() {
            guard let dump = try? await workspace.dump(focus: focus, .nonCancellable) else { return .fail(io.err(bugPrompt())) }
            dumps.append(dump)
        }
        guard let json = JSONEncoder.aeroSpaceDefault.encodeToString(Json.array(dumps)) else { return .fail(io.err("Can't encode the tree to JSON")) }
        return .succ(io.out(json))
    }
}

extension Workspace {
    @MainActor
    fileprivate func dump(focus: LiveFocus, _ cm: CancellationMode) async throws -> Json {
        let monitor = workspaceMonitorInfo
        let measurement = try await measureLayout()
        var floatingWindows: [Json] = []
        for window in self.floatingWindows {
            let rect = if let rect = window.unhiddenFloatingRect { rect } else { try await window.getAxRect(cm) }
            floatingWindows.append(try await window.dump(path: nil, rect: rect, cm))
        }
        return .dict([
            "workspace": .string(name),
            "workspace-is-focused": .bool(focus.workspace == self),
            "workspace-is-visible": .bool(isVisible),
            "workspace-rect": monitor.visibleRectPaddedByOuterGaps.dump,
            "monitor-id": monitor.monitorId_oneBased.map { Json.int(Int64($0)) } ?? .null,
            "root": try await rootTilingContainer.dump(path: ContainerPath([]), measurement, cm),
            "floating-windows": .array(floatingWindows),
        ])
    }
}

extension TreeNode {
    @MainActor
    fileprivate func dump(path: ContainerPath, _ measurement: LayoutMeasurement, _ cm: CancellationMode) async throws -> Json {
        switch tilingTreeNodeCasesOrDie() {
            case .tilingContainer(let container):
                var children: [Json] = []
                for (index, child) in container.inhabitedChildren.enumerated() {
                    children.append(try await child.dump(path: ContainerPath(path.indices + [index]), measurement, cm))
                }
                return .dict([
                    "type": .string("container"),
                    "path": .string(path.description),
                    "layout": .string(container.layoutName),
                    "rect": measurement.rect(of: container)?.dump ?? .null,
                    "children": .array(children),
                ])
            case .window(let window):
                return try await window.dump(path: path, rect: measurement.rect(of: window), cm)
        }
    }
}

extension Window {
    @MainActor
    fileprivate func dump(path: ContainerPath?, rect: Rect?, _ cm: CancellationMode) async throws -> Json {
        var dict: Json.JsonDict = [
            "type": .string("window"),
            "window-id": .int(Int64(windowId.rawId)),
            "window-title": .string(try await getTitle(cm)),
            "window-is-fullscreen": .bool(isFullscreen),
            "app-bundle-id": .stringOrNull(app.rawAppBundleId),
            "app-name": .stringOrNull(app.name),
            "app-pid": .int(Int64(app.pid)),
            "rect": rect?.dump ?? .null,
        ]
        if let path {
            dict["path"] = .string(path.description)
        }
        return .dict(dict)
    }
}

extension Rect {
    /// Frames are rounded to integer points. That's the precision the AX API works with anyway
    fileprivate var dump: Json {
        .dict([
            "x": .int(Int64(topLeftX.rounded())),
            "y": .int(Int64(topLeftY.rounded())),
            "width": .int(Int64(width.rounded())),
            "height": .int(Int64(height.rounded())),
        ])
    }
}

extension TilingContainer {
    /// The layout as `aerospace layout` names it: h_tiles, v_tiles, h_accordion, v_accordion
    var layoutName: String {
        switch (layout, orientation) {
            case (.tiles, .h): LayoutCmdArgs.LayoutDescription.h_tiles.rawValue
            case (.tiles, .v): LayoutCmdArgs.LayoutDescription.v_tiles.rawValue
            case (.accordion, .h): LayoutCmdArgs.LayoutDescription.h_accordion.rawValue
            case (.accordion, .v): LayoutCmdArgs.LayoutDescription.v_accordion.rawValue
        }
    }
}
