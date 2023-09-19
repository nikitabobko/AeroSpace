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
        if let parent = window.parent as? TilingContainer {
            parent.layout = targetLayout?.simpleLayout ?? errorT("TODO")
            parent.orientation = targetLayout?.orientation ?? errorT("TODO")
        } else {
            precondition(window.parent is Workspace)
            // todo
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

private extension MacWindow {
    var configLayout: ConfigLayout {
        if let parent = parent as? TilingContainer {
            switch parent.layout {
            case .List:
                return parent.orientation == .H ? .h_list : .v_list
            case .Accordion:
                return parent.orientation == .H ? .h_accordion : .v_accordion
            }
        } else {
            return .floating
        }
    }
}
