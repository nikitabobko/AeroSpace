import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if args.root {
            return changeRootLayout(io, root: target.workspace.rootTilingContainer, toggleBetween: args.toggleBetween.val)
        }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        return try await changeWindowLayout(io, window: window, targetWorkspace: target.workspace, toggleBetween: args.toggleBetween.val)
    }
}

@MainActor private func changeWindowLayout(
    _ io: CmdIo,
    window: Window,
    targetWorkspace: Workspace,
    toggleBetween: [LayoutCmdArgs.LayoutDescription],
) async throws -> BinaryExitCode {
    let targetDescription = toggleBetween.first(where: { !window.matchesDescription($0) })
        ?? toggleBetween.first.orDie()
    if window.matchesDescription(targetDescription) { return .fail }
    if let (targetLayout, targetOrientation) = targetDescription.tilingMapping {
        return changeTilingLayout(io, targetLayout: targetLayout, targetOrientation: targetOrientation, window: window)
    }
    switch targetDescription {
        case .tiling:
            guard let parent = window.parent else { return .fail }
            switch parent.cases {
                case .macosPopupWindowsContainer:
                    return .fail // Impossible
                case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                    return .fail(io.err("Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. This behavior is subject to change"))
                case .tilingContainer:
                    return .succ // Nothing to do
                case .workspace(let workspace):
                    window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                    try await window.relayoutWindow(on: workspace, forceTile: true)
                    return .succ
            }
        case .floating:
            window.bindAsFloatingWindow(to: targetWorkspace)
            if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
            return .succ
        default:
            return .fail // unreachable: tilingMapping above handles all tiling layouts
    }
}

@MainActor private func changeTilingLayout(_ io: CmdIo, targetLayout: Layout?, targetOrientation: Orientation?, window: Window) -> BinaryExitCode {
    guard let parent = window.parent else { return .fail }
    switch parent.cases {
        case .tilingContainer(let parent):
            let targetOrientation = targetOrientation ?? parent.orientation
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            parent.changeOrientation(targetOrientation)
            return .succ
        case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return .fail(io.err("The window is non-tiling"))
    }
}

@MainActor private func changeRootLayout(
    _ io: CmdIo,
    root: TilingContainer,
    toggleBetween: [LayoutCmdArgs.LayoutDescription],
) -> BinaryExitCode {
    let targetDescription = toggleBetween.first(where: { !root.matchesDescription($0) })
        ?? toggleBetween.first.orDie()
    if root.matchesDescription(targetDescription) { return .fail }
    guard let (targetLayout, targetOrientation) = targetDescription.tilingMapping else {
        return .fail(io.err("'\(targetDescription.rawValue)' is a window placement mode and is not valid with --root")) // unreachable: rejected at parse time
    }
    root.layout = targetLayout ?? root.layout
    root.changeOrientation(targetOrientation ?? root.orientation)
    return .succ
}

extension LayoutCmdArgs.LayoutDescription {
    /// Tiling-layout descriptors map to (layout?, orientation?). `tiling`/`floating` are window
    /// placement modes rather than tiling layouts and return nil.
    fileprivate var tilingMapping: (layout: Layout?, orientation: Orientation?)? {
        return switch self {
            case .h_accordion: (.accordion, .h)
            case .v_accordion: (.accordion, .v)
            case .h_tiles:     (.tiles, .h)
            case .v_tiles:     (.tiles, .v)
            case .accordion:   (.accordion, nil)
            case .tiles:       (.tiles, nil)
            case .horizontal:  (nil, .h)
            case .vertical:    (nil, .v)
            case .tiling, .floating: nil
        }
    }
}

extension TilingContainer {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   self.layout == .accordion
            case .tiles:       self.layout == .tiles
            case .horizontal:  orientation == .h
            case .vertical:    orientation == .v
            case .h_accordion: self.layout == .accordion && orientation == .h
            case .v_accordion: self.layout == .accordion && orientation == .v
            case .h_tiles:     self.layout == .tiles && orientation == .h
            case .v_tiles:     self.layout == .tiles && orientation == .v
            case .tiling:      true  // a TilingContainer is by definition tiling
            case .floating:    false // a TilingContainer is never floating; rejected at parse time with --root
        }
    }
}

extension Window {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   (parent as? TilingContainer)?.layout == .accordion
            case .tiles:       (parent as? TilingContainer)?.layout == .tiles
            case .horizontal:  (parent as? TilingContainer)?.orientation == .h
            case .vertical:    (parent as? TilingContainer)?.orientation == .v
            case .h_accordion: (parent as? TilingContainer).map { $0.layout == .accordion && $0.orientation == .h } == true
            case .v_accordion: (parent as? TilingContainer).map { $0.layout == .accordion && $0.orientation == .v } == true
            case .h_tiles:     (parent as? TilingContainer).map { $0.layout == .tiles && $0.orientation == .h } == true
            case .v_tiles:     (parent as? TilingContainer).map { $0.layout == .tiles && $0.orientation == .v } == true
            case .tiling:      parent is TilingContainer
            case .floating:    parent is Workspace
        }
    }
}
