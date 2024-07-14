import AppKit
import Common

/// Problem ID-B6E178F2: It's not first-class citizen command in AeroSpace model, since it interacts with macOS API directly.
/// Consecutive macos-native-fullscreen commands may not works as expected (because macOS may report correct state with a
/// delay), or may flicker
///
/// The same applies to macos-native-minimize command
struct MacosNativeFullscreenCommand: Command {
    let args: MacosNativeFullscreenCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        guard let window = focus.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        let axWindow = window.asMacWindow().axWindow
        let prevState = window.isMacosFullscreen
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !prevState
        }
        if newState == prevState {
            io.err((newState ? "Already fullscreen. " : "Already not fullscreen. ") +
                "Tip: use --fail-if-noop to exit with non-zero exit code")
            return !args.failIfNoop
        }
        if axWindow.set(Ax.isFullscreenAttr, newState) {
            guard let workspace = window.visualWorkspace else {
                return io.err(windowIsntPartOfTree(window))
            }
            if newState { // Enter fullscreen
                window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            } else { // Exit fullscreen
                switch window.layoutReason {
                    case .macos(let prevParentKind):
                        exitMacOsNativeUnconventionalState(window: window, prevParentKind: prevParentKind, workspace: workspace)
                    default:
                        window.relayoutWindow(on: workspace)
                }
            }
            return true
        } else {
            return io.err("AX API returned error")
        }
    }
}
