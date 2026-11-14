import AppKit
import Common

/// dwm-like "zoom": make the focused window the master of its workspace.
///
/// The master is the window that occupies the placeholder slot `1` of the workspace layout skeleton
/// (`[workspace-layout]`). Workspaces without a layout skeleton treat the first window in the visual order as the
/// master. The command swaps the focused window with the current master, so the promoted window stays in the master
/// slot until the set of windows changes.
struct PromoteCommand: Command {
    let args: PromoteCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let master = resolveMaster(in: target.workspace) else { return .succ }
        if master === window { return .succ } // Already the master
        switch window.windowParentCases {
            case .tilingContainer:
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

    @MainActor
    private func resolveMaster(in workspace: Workspace) -> Window? {
        let windows = workspace.rootTilingContainer.allInhabitedLeafWindowsRecursive
        if let skeleton = config.workspaceLayout[workspace.name] {
            return skeleton.windowInPlaceholder(1, windows: windows)
        }
        return windows.first
    }
}

private let promoteMacosUnconventionalWindow = "promoting macOS fullscreen, minimized windows and windows of hidden apps " +
    "isn't yet supported"
