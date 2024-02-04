import Common

struct SplitCommand: Command {
    let args: SplitCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        if config.enableNormalizationFlattenContainers {
            state.stderr.append("'split' has no effect when 'enable-normalization-flatten-containers' normalization enabled")
            return false
        }
        guard let window = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
        }
        switch window.parent.cases {
        case .workspace:
            return false // Nothing to do for floating windows
        case .tilingContainer(let parent):
            let orientation: Orientation
            switch args.arg.val {
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
        return true
    }
}
