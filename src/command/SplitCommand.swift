struct SplitCommand: Command {
    enum SplitArg: String {
        case horizontal, vertical, opposite
    }

    let splitArg: SplitArg

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        if config.enableNormalizationFlattenContainers {
            return // 'split' doesn't work with "flatten container" normalization enabled
        }
        guard let window = focusedWindowOrEffectivelyFocused else { return }
        switch window.parent.kind {
        case .workspace:
            return // Nothing to do for floating windows
        case .tilingContainer(let parent):
            let orientation: Orientation
            switch splitArg {
            case .vertical:
                orientation = .v
            case .horizontal:
                orientation = .h
            case .opposite:
                orientation = parent.orientation.opposite
            }
            if parent.children.count == 1 {
                parent.changeOrientation(orientation)
            } else {
                let data = window.unbindFromParent()
                let newParent = TilingContainer(
                    parent: parent,
                    adaptiveWeight: data.adaptiveWeight,
                    orientation,
                    .tiles,
                    index: data.index
                )
                window.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
            }
        }
    }
}
