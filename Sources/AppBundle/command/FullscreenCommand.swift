import AppKit
import Common

struct FullscreenCommand: Command {
    let args: FullscreenCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append(noWindowIsFocused)
            return false
        }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isFullscreen
        }
        if newState == window.isFullscreen {
            if newState {
                state.stderr.append("Already fullscreen")
            } else {
                state.stderr.append("Already not fullscreen")
            }
            return false
        }
        window.isFullscreen = newState

        // Focus on its own workspace
        window.markAsMostRecentChild()
        return true
    }
}

let noWindowIsFocused = "No window is focused"
