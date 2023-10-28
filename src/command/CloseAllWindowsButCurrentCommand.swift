class CloseAllWindowsButCurrentCommand: Command {
    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        guard let focused = focusedWindowOrEffectivelyFocused else { return }
        for window in focused.workspace.allLeafWindowsRecursive {
            if window != focused {
                window.close()
            }
        }
    }
}