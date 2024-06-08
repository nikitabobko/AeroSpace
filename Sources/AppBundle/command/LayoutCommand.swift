import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            return state.failCmd(msg: noWindowIsFocused)
        }
        let targetDescription = args.toggleBetween.val.first(where: { !window.matchesDescription($0) })
            ?? args.toggleBetween.val.first!
        if window.matchesDescription(targetDescription) { return false }
        switch targetDescription {
            case .h_accordion:
                return changeTilingLayout(state, targetLayout: .accordion, targetOrientation: .h, window: window)
            case .v_accordion:
                return changeTilingLayout(state, targetLayout: .accordion, targetOrientation: .v, window: window)
            case .h_tiles:
                return changeTilingLayout(state, targetLayout: .tiles, targetOrientation: .h, window: window)
            case .v_tiles:
                return changeTilingLayout(state, targetLayout: .tiles, targetOrientation: .v, window: window)
            case .accordion:
                return changeTilingLayout(state, targetLayout: .accordion, targetOrientation: nil, window: window)
            case .tiles:
                return changeTilingLayout(state, targetLayout: .tiles, targetOrientation: nil, window: window)
            case .horizontal:
                return changeTilingLayout(state, targetLayout: nil, targetOrientation: .h, window: window)
            case .vertical:
                return changeTilingLayout(state, targetLayout: nil, targetOrientation: .v, window: window)
            case .tiling:
                switch window.parent.cases {
                    case .macosPopupWindowsContainer:
                        return false // Impossible
                    case .macosInvisibleWindowsContainer:
                        return state.failCmd(msg: "Can't change layout of macOS invisible windows (hidden application or minimized windows). This behavior is subject to change")
                    case .macosFullscreenWindowsContainer:
                        return state.failCmd(msg: "Can't change layout of macOS fullscreen windows. This behavior is subject to change")
                    case .tilingContainer:
                        return true // Nothing to do
                    case .workspace(let workspace):
                        window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                        window.relayoutWindow(on: workspace, forceTile: true)
                        return true
                }
            case .floating:
                let workspace = state.subject.workspace
                window.bindAsFloatingWindow(to: workspace)
                guard let topLeftCorner = window.getTopLeftCorner() else { return false }
                return window.setFrame(topLeftCorner, window.lastFloatingSize)
        }
    }
}

private func changeTilingLayout(_ state: CommandMutableState, targetLayout: Layout?, targetOrientation: Orientation?, window: Window) -> Bool {
    switch window.parent.cases {
        case .tilingContainer(let parent):
            let targetOrientation = targetOrientation ?? parent.orientation
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            parent.changeOrientation(targetOrientation)
            return true
        case .workspace, .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer, .macosPopupWindowsContainer:
            return state.failCmd(msg: "The window is non-tiling")
    }
}

private extension Window {
    func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   (parent as? TilingContainer)?.layout == .accordion
            case .tiles:       (parent as? TilingContainer)?.layout == .tiles
            case .horizontal:  (parent as? TilingContainer)?.orientation == .h
            case .vertical:    (parent as? TilingContainer)?.orientation == .v
            case .h_accordion: (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .h } == true
            case .v_accordion: (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .v } == true
            case .h_tiles:     (parent as? TilingContainer)?.lets { $0.layout == .tiles && $0.orientation == .h } == true
            case .v_tiles:     (parent as? TilingContainer)?.lets { $0.layout == .tiles && $0.orientation == .v } == true
            case .tiling:      parent is TilingContainer
            case .floating:    parent is Workspace
        }
    }
}
