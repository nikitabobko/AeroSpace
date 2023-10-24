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
        let targetLayout: ConfigLayout? = toggleBetween.firstIndex(of: window.configLayout)
            .flatMap { toggleBetween.getOrNil(atIndex: $0 + 1) }
            .orElse { toggleBetween.first }
            .map { $0 == .main ? config.mainLayout : $0 }
        switch window.parent.kind {
        case .tilingContainer(let parent):
            parent.layout = targetLayout?.simpleLayout ?? errorT("TODO")
            if config.enableNormalizationOppositeOrientationForNestedContainers {
                var orientation = targetLayout?.orientation ?? errorT("TODO")
                parent.parentsWithSelf
                    .prefix(while: { $0 is TilingContainer })
                    .filterIsInstance(of: TilingContainer.self)
                    .forEach {
                        $0.orientation = orientation
                        orientation = orientation.opposite
                    }
            } else {
                parent.orientation = targetLayout?.orientation ?? errorT("TODO")
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
            return .Accordion
        case .h_list, .v_list:
            return .List
        case .floating, .tiling, .sticky, .main:
            return nil
        }
    }

    var orientation: Orientation? {
        switch self {
        case .h_accordion, .h_list:
            return .H
        case .v_accordion, .v_list:
            return .V
        case .floating, .tiling, .sticky, .main:
            return nil
        }
    }
}

private extension Window {
    var configLayout: ConfigLayout {
        switch parent.kind {
        case .tilingContainer(let parent):
            switch parent.layout {
            case .List:
                return parent.orientation == .H ? .h_list : .v_list
            case .Accordion:
                return parent.orientation == .H ? .h_accordion : .v_accordion
            }
        case .workspace:
            return .floating
        }
    }
}
