import AppKit
import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        guard let window = focus.windowOrNil else {
            return io.err("Empty workspace")
        }
        if window.macAppUnsafe.axApp.get(Ax.windowsAttr)?.count == 1 && args.quitIfLastWindow {
            if window.macAppUnsafe.nsApp.terminate() {
                window.asMacWindow().garbageCollect()
                return true
            } else {
                return io.err("Failed to quit '\(window.app.name ?? "Unknown app")'")
            }
        } else {
            if window.close() {
                window.asMacWindow().garbageCollect()
                return true
            } else {
                return io.err("Can't close '\(window.app.name ?? "Unknown app")' window. Probably the window doesn't have a close button")
            }
        }
    }
}
