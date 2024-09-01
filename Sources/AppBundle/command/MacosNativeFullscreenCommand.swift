import AppKit
import Common

/// Problem ID-B6E178F2: It's not first-class citizen command in AeroSpace model, since it interacts with macOS API directly.
/// Consecutive macos-native-fullscreen commands may not works as expected (because macOS may report correct state with a
/// delay), or may flicker
///
/// The same applies to macos-native-minimize command
struct MacosNativeFullscreenCommand: Command {
    let args: MacosNativeFullscreenCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            return state.failCmd(msg: "No window in focus")
        }
        let axWindow = window.asMacWindow().axWindow
        let prevState = window.isMacosFullscreen
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !prevState
        }
        if newState == prevState {
            return state.failCmd(msg: newState ? "Already fullscreen" : "Already not fullscreen")
        }
        if axWindow.set(Ax.isFullscreenAttr, newState) {
            guard let workspace = window.visualWorkspace else {
                return state.failCmd(msg: windowIsntPartOfTree(window))
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
            return state.failCmd(msg: "Failed")
        }
    }
}
