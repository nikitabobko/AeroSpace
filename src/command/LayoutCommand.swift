struct LayoutCommand: Command {
    let toggleBetween: [LayoutDescription]

    enum LayoutDescription: String {
        case accordion, list
        case horizontal, vertical
        case h_accordion, v_accordion, h_list, v_list
        case tiling, floating
    }

    init?(toggleBetween: [LayoutDescription]) {
        if toggleBetween.isEmpty {
            return nil
        }
        self.toggleBetween = toggleBetween
    }

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        guard let window = focusedWindowOrEffectivelyFocused else { return }
        let targetDescription: LayoutDescription = toggleBetween.firstIndex(where: { window.matchesDescription($0) })
            .flatMap { toggleBetween.getOrNil(atIndex: $0 + 1) }
            .orElse { toggleBetween.first! }
        if window.matchesDescription(targetDescription) {
            return
        }
        switch targetDescription {
        case .h_accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: .h, window: window)
        case .v_accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: .v, window: window)
        case .h_list:
            changeTilingLayout(targetLayout: .list, targetOrientation: .h, window: window)
        case .v_list:
            changeTilingLayout(targetLayout: .list, targetOrientation: .v, window: window)
        case .accordion:
            changeTilingLayout(targetLayout: .accordion, targetOrientation: nil, window: window)
        case .list:
            changeTilingLayout(targetLayout: .list, targetOrientation: nil, window: window)
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
            let padding = CGFloat(30)
            guard let size = window.getSize() else { break }
            guard let topLeftCorner = window.getTopLeftCorner() else { break }
            window.setTopLeftCorner(topLeftCorner.addingXOffset(padding).addingYOffset(padding))
            window.setSize(window.lastFloatingSize
                ?? CGSize(width: size.width - 2 * padding, height: size.height - 2 * padding))
        }
    }
}

private func changeTilingLayout(targetLayout: Layout?, targetOrientation: Orientation?, window: Window) {
    switch window.parent.kind {
    case .tilingContainer(let parent):
        let targetOrientation = targetOrientation ?? parent.orientation
        let targetLayout = targetLayout ?? parent.layout
        parent.layout = targetLayout
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            var orientation = targetOrientation
            parent.parentsWithSelf
                .prefix(while: { $0 is TilingContainer })
                .filterIsInstance(of: TilingContainer.self)
                .forEach {
                    $0.orientation = orientation
                    orientation = orientation.opposite
                }
        } else {
            parent.orientation = targetOrientation
        }
    case .workspace:
        break // Do nothing for non-tiling windows
    }
}

private extension Window {
    func matchesDescription(_ layout: LayoutCommand.LayoutDescription) -> Bool {
        switch layout {
        case .accordion:
            return (parent as? TilingContainer)?.layout == .accordion
        case .list:
            return (parent as? TilingContainer)?.layout == .list
        case .horizontal:
            return (parent as? TilingContainer)?.orientation == .h
        case .vertical:
            return (parent as? TilingContainer)?.orientation == .v
        case .h_accordion:
            return (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .h } == true
        case .v_accordion:
            return (parent as? TilingContainer)?.lets { $0.layout == .accordion && $0.orientation == .v } == true
        case .h_list:
            return (parent as? TilingContainer)?.lets { $0.layout == .list && $0.orientation == .h } == true
        case .v_list:
            return (parent as? TilingContainer)?.lets { $0.layout == .list && $0.orientation == .v } == true
        case .tiling:
            return parent is TilingContainer
        case .floating:
            return parent is Workspace
        }
    }
}
