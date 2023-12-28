import Common

struct LayoutCommand: Command {
    let info: CmdStaticInfo = LayoutCmdArgs.info
    let args: LayoutCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stdout.append(noWindowIsFocused)
            return false
        }
        let targetDescription = args.toggleBetween.val.first(where: { !window.matchesDescription($0) })
            ?? args.toggleBetween.val.first!
        if window.matchesDescription(targetDescription) { return false }
        var result = true
        switch targetDescription {
        case .h_accordion:
            result = changeTilingLayout(targetLayout: .accordion, targetOrientation: .h, window: window)
        case .v_accordion:
            result = changeTilingLayout(targetLayout: .accordion, targetOrientation: .v, window: window)
        case .h_tiles:
            result = changeTilingLayout(targetLayout: .tiles, targetOrientation: .h, window: window)
        case .v_tiles:
            result = changeTilingLayout(targetLayout: .tiles, targetOrientation: .v, window: window)
        case .accordion:
            result = changeTilingLayout(targetLayout: .accordion, targetOrientation: nil, window: window)
        case .tiles:
            result = changeTilingLayout(targetLayout: .tiles, targetOrientation: nil, window: window)
        case .horizontal:
            result = changeTilingLayout(targetLayout: nil, targetOrientation: .h, window: window)
        case .vertical:
            result = changeTilingLayout(targetLayout: nil, targetOrientation: .v, window: window)
        case .tiling:
            switch window.parent.kind {
            case .workspace:
                window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
            case .tilingContainer:
                error("Impossible")
            }
            let data = getBindingDataForNewTilingWindow(window.unbindFromParent().parent.workspace)
            window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        case .floating:
            let workspace = window.unbindFromParent().parent.workspace
            window.bindAsFloatingWindow(to: workspace)
            guard let topLeftCorner = window.getTopLeftCorner() else { break }
            let offset = CGPoint(
                x: abs(topLeftCorner.x - workspace.monitor.rect.topLeftX).takeIf { $0 < 30 } ?? 0,
                y: abs(topLeftCorner.y - workspace.monitor.rect.topLeftY).takeIf { $0 < 30 } ?? 0
            )
            window.setTopLeftCorner(topLeftCorner + offset)
            if let lastFloatingSize = window.lastFloatingSize {
                window.setSize(lastFloatingSize)
            }
        }
        return result
    }
}

private func changeTilingLayout(targetLayout: Layout?, targetOrientation: Orientation?, window: Window) -> Bool {
    switch window.parent.kind {
    case .tilingContainer(let parent):
        let targetOrientation = targetOrientation ?? parent.orientation
        let targetLayout = targetLayout ?? parent.layout
        parent.layout = targetLayout
        parent.changeOrientation(targetOrientation)
        return true
    case .workspace:
        return false // Do nothing for non-tiling windows
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
