import Common

/// Problem B6E178F2: It's not first-class citizen command in AeroSpace model, since it interacts with macOS API directly.
/// Consecutive macos-native-fullscreen commands may not works as expected (because macOS may report correct state with a
/// delay), or may flicker
///
/// The same applies to macos-native-minimize command
struct MacosNativeFullscreenCommand: Command { // todo only allow as the latest command in sequence
    let args: MacosNativeFullscreenCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append("No window in focus")
            return false
        }
        let axWindow = window.asMacWindow().axWindow
        let success = axWindow.set(Ax.isFullscreenAttr, !window.isMacosFullscreen)
        if !success { state.stderr.append("Failed") }
        // todo attach or detach to appropriate parent
        return success
    }
}
