struct FullscreenCommand: Command {
    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        guard let window = focusedWindowOrEffectivelyFocused else { return }
        window.isFullscreen = !window.isFullscreen
    }
}
