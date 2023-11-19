struct LayoutCommand: Command {
    let toggleBetween: [LayoutDescription]

    enum LayoutDescription: String {
        case accordion, tiles
        case horizontal, vertical
        case h_accordion, v_accordion, h_tiles, v_tiles
        case tiling, floating
    }

    init?(toggleBetween: [LayoutDescription]) {
        if toggleBetween.isEmpty {
            return nil
        }
        self.toggleBetween = toggleBetween
    }

    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        guard let window = state.window else { return }
        let targetDescription: LayoutDescription = toggleBetween.first(where: { !window.matchesDescription($0) })
            ?? toggleBetween.first!
        if window.matchesDescription(targetDescription) {
            return
        }
        switch targetDescription {
        case .h_accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: .h, window: window)
        case .v_accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: .v, window: window)
        case .h_tiles:
            changeTilingLayout(targetLayout: .tiles, targetOrientation: .h, window: window)
        case .v_tiles:
            changeTilingLayout(targetLayout: .tiles, targetOrientation: .v, window: window)
        case .accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: nil, window: window)
        case .tiles:
            changeTilingLayout(targetLayout: .tiles, targetOrientation: nil, window: window)
        case .horizontal:
            changeTilingLayout(targetLayout: nil, targetOrientation: .h, window: window)
        case .vertical:
            changeTilingLayout(targetLayout: nil, targetOrientation: .v, window: window)
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
            // todo doesn't work as expected on-window-detected callback
            //guard let size = window.getSize() else { break }
            //guard let topLeftCorner = window.getTopLeftCorner() else { break }
            //let offset = CGFloat(30)
            //window.setTopLeftCorner(topLeftCorner.addingXOffset(offset).addingYOffset(offset))
            //window.setSize(window.lastFloatingSize
            //    ?? CGSize(width: size.width - 2 * offset, height: size.height - 2 * offset))
        }
    }
}

extension String {
    func parseLayoutDescription() -> LayoutCommand.LayoutDescription? {
        if let parsed = LayoutCommand.LayoutDescription(rawValue: self) {
            return parsed
        } else if self == "list" {
            return .tiles
        } else if self == "h_list" {
            return .h_tiles
        } else if self == "v_list" {
            return .v_tiles
        }
        return nil
    }
}

private func changeTilingLayout(targetLayout: Layout?, targetOrientation: Orientation?, window: Window) {
    switch window.parent.kind {
    case .tilingContainer(let parent):
        let targetOrientation = targetOrientation ?? parent.orientation
        let targetLayout = targetLayout ?? parent.layout
        parent.layout = targetLayout
        parent.changeOrientation(targetOrientation)
    case .workspace:
        break // Do nothing for non-tiling windows
    }
}

private extension Window {
    func matchesDescription(_ layout: LayoutCommand.LayoutDescription) -> Bool {
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
