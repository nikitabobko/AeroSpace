import AppKit
import Common

struct SplitCommand: Command {
    let args: SplitCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        if config.enableNormalizationFlattenContainers {
            return state.failCmd(msg: "'split' has no effect when 'enable-normalization-flatten-containers' normalization enabled. My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.")
        }
        guard let window = state.subject.windowOrNil else {
            return state.failCmd(msg: noWindowIsFocused)
        }
        switch window.parent.cases {
            case .workspace:
                // Nothing to do for floating and macOS native fullscreen windows
                return state.failCmd(msg: "Can't split floating windows")
            case .tilingContainer(let parent):
                let orientation: Orientation = switch args.arg.val {
                    case .vertical: .v
                    case .horizontal: .h
                    case .opposite: parent.orientation.opposite
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
                return true
            case .macosMinimizedWindowsContainer:
                return state.failCmd(msg: "Can't split invisible windows (minimized windows or windows of hidden apps). This behavior may change in the future")
            case .macosFullscreenWindowsContainer:
                return state.failCmd(msg: "Can't split fullscreen windows. This behavior may change in the future")
            case .macosPopupWindowsContainer:
                return false // Impossible
        }
    }
}
