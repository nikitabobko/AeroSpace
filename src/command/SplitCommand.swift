struct SplitCommand: Command {
    let args: SplitCmdArgs

    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        if config.enableNormalizationFlattenContainers {
            return // 'split' doesn't work with "flatten container" normalization enabled
        }
        guard let window = subject.windowOrNil else { return }
        switch window.parent.kind {
        case .workspace:
            return // Nothing to do for floating windows
        case .tilingContainer(let parent):
            let orientation: Orientation
            switch args.arg {
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
