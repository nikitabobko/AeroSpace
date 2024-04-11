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
            state.stderr.append("No window in focus")
            return false
        }
        let axWindow = window.asMacWindow().axWindow
        let prevState = window.isMacosFullscreen
        let newState: Bool
        switch args.toggle {
            case .on:
                newState = true
            case .off:
                newState = false
            case .toggle:
                newState = !prevState
        }
        if newState == prevState {
            if newState {
                state.stderr.append("Already fullscreen")
            } else {
                state.stderr.append("Already not fullscreen")
            }
            return false
        }
        if axWindow.set(Ax.isFullscreenAttr, newState) {
            let workspace = window.unbindFromParent().parent.workspace ?? Workspace.focused
            if newState {
                window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
            } else {
                switch window.layoutReason {
                    case .macos(let prevParentKind):
                        exitMacOsNativeOrInvisibleState(window: window, prevParentKind: prevParentKind, workspace: workspace)
                    default:
                        window.relayoutWindow(on: workspace)
                }
            }
            return true
        } else {
            state.stderr.append("Failed")
            return false
        }
    }
}
