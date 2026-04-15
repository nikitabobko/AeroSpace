import AppKit
import Common

struct SplitCommand: Command {
    let args: SplitCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        if config.enableNormalizationFlattenContainers {
            return .fail(io.err("'split' has no effect when 'enable-normalization-flatten-containers' normalization enabled. My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'."))
        }
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let parent = window.parent else { return .fail }
        switch parent.cases {
            case .workspace:
                // Nothing to do for floating and macOS native fullscreen windows
                return .fail(io.err("Can't split floating windows"))
            case .tilingContainer(let parent):
                let orientation: Orientation = switch args.arg.val {
                    case .vertical: .v
                    case .horizontal: .h
                    case .opposite: parent.orientation.opposite
                }
                if parent.layout == .scrolling && orientation != .h {
                    return .fail(io.err("The scrolling layout is always horizontal"))
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
                        index: data.index,
                    )
                    window.bind(to: newParent, adaptiveWeight: WEIGHT_AUTO, index: 0)
                }
                return .succ
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return .fail(io.err("Can't split macos fullscreen, minimized windows and windows of hidden apps. This behavior may change in the future"))
            case .macosPopupWindowsContainer:
                return .fail // Impossible
        }
    }
}
