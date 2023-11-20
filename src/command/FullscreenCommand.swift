struct FullscreenCommand: Command {
    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        guard let window = subject.windowOrNil else { return }
        window.isFullscreen = !window.isFullscreen
    }
}
