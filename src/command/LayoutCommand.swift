/// Syntax:
/// layout (main|h_accordion|v_accordion|h_list|v_list|floating|tiling)...
struct LayoutCommand: Command {
    let toggleBetween: [ConfigLayout]

    init?(toggleBetween: [ConfigLayout]) {
        if toggleBetween.isEmpty || toggleBetween.toSet().count != toggleBetween.count {
            return nil
        }
        self.toggleBetween = toggleBetween
    }

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        guard let window = focusedWindowOrEffectivelyFocused else { return }
        let targetLayout: ConfigLayout = toggleBetween.firstIndex(of: window.configLayout)
            .flatMap { toggleBetween.getOrNil(atIndex: $0 + 1) }
            .orElse { toggleBetween.first! }
        switch window.parent.kind {
        case .tilingContainer(let parent):
            parent.layout = targetLayout.simpleLayout ?? errorT("TODO")
            if config.enableNormalizationOppositeOrientationForNestedContainers {
                var orientation = targetLayout.orientation ?? errorT("TODO")
                parent.parentsWithSelf
                    .prefix(while: { $0 is TilingContainer })
                    .filterIsInstance(of: TilingContainer.self)
                    .forEach {
                        $0.orientation = orientation
                        orientation = orientation.opposite
                    }
            } else {
                parent.orientation = targetLayout.orientation ?? errorT("TODO")
            }
        case .workspace:
            break // todo
        }
    }
}

private extension ConfigLayout {
    var simpleLayout: Layout? {
        switch self {
        case .h_accordion, .v_accordion:
            return .accordion
        case .h_list, .v_list:
            return .list
        case .floating, .tiling:
            return nil
        }
    }

    var orientation: Orientation? {
        switch self {
        case .h_accordion, .h_list:
            return .h
        case .v_accordion, .v_list:
            return .v
        case .floating, .tiling:
            return nil
        }
    }
}

private extension Window {
    var configLayout: ConfigLayout {
        switch parent.kind {
        case .tilingContainer(let parent):
            switch parent.layout {
            case .list:
                return parent.orientation == .h ? .h_list : .v_list
            case .accordion:
                return parent.orientation == .h ? .h_accordion : .v_accordion
            }
        case .workspace:
            return .floating
        }
    }
}
