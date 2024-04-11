import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
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
            case .macosInvisibleWindowsContainer:
                state.stderr.append("Can't change layout of macOS invisible windows (hidden application or minimized windows). This behavior is subject to change")
                return false
            case .macosFullscreenWindowsContainer:
                state.stderr.append("Can't change layout of macOS fullscreen windows. This behavior is subject to change")
                return false
            case .tilingContainer:
                return true // Nothing to do
            case .workspace(let workspace):
                window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                window.unbindFromParent()
                let data = getBindingDataForNewTilingWindow(workspace)
                window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
                return true
            }
        case .floating:
            let workspace = state.subject.workspace // Capture workspace before unbind ID-1A4CF7C5
            window.unbindFromParent() // ID-1A4CF7C5
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
    case .workspace, .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer:
        state.stderr.append("The window is non-tiling")
        return false
    }
}

private extension Window {
    func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        switch layout {
        case .accordion:
            return (parent as? TilingContainer)?.layout == .accordion
        case .tiles:
            return (parent as? TilingContainer)?.layout == .tiles
        case .horizontal:
            return (parent as? TilingContainer)?.orientation == .h
        case .vertical:
            return (parent as? TilingContainer)?.orientation == .v
        case .h_accordion:
            return (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .h } == true
        case .v_accordion:
            return (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .v } == true
        case .h_tiles:
            return (parent as? TilingContainer)?.lets { $0.layout == .tiles && $0.orientation == .h } == true
        case .v_tiles:
            return (parent as? TilingContainer)?.lets { $0.layout == .tiles && $0.orientation == .v } == true
        case .tiling:
            return parent is TilingContainer
        case .floating:
            return parent is Workspace
        }
    }
}
