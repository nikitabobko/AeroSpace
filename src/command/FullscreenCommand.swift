struct FullscreenCommand: Command {
    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        guard let window = state.window else { return }
        window.isFullscreen = !window.isFullscreen
    }
}
