import AppKit
import Common

/// dwm-like "zoom": make the focused window the master of its workspace.
///
/// The master is the first window in the visual order of the workspace, i.e. the window that occupies placeholder `1`
/// of a layout skeleton (`[workspace-layout]`). The command swaps the focused window with the current master, so the
/// layout skeleton keeps the promoted window in the master slot until the set of windows changes.
struct PromoteCommand: Command {
    let args: PromoteCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let master = target.workspace.rootTilingContainer.allInhabitedLeafWindowsRecursive.first
        switch window.windowParentCases {
            case .tilingContainer:
                guard let master else { return .succ }
                if master === window { return .succ } // Already the master
                swapWindows(mruDominant: window, master)
                return .succ
            case .floatingWindowsContainer:
                return .fail(io.err("promoting floating windows isn't yet supported"))
            case .macosMinimizedWindowsContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer:
                return .fail(io.err(promoteMacosUnconventionalWindow))
            case .macosPopupWindowsContainer:
                return .fail(io.err(bugPrompt()))
            case nil:
                return .fail
        }
    }
}

private let promoteMacosUnconventionalWindow = "promoting macOS fullscreen, minimized windows and windows of hidden apps " +
    "isn't yet supported"
