import AppKit
import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err("Empty workspace")
        }
        // Access ax directly. Not cool :(
        if args.quitIfLastWindow && window.macAppUnsafe.axApp.get(Ax.windowsAttr)?.count == 1 {
            if window.macAppUnsafe.nsApp.terminate() {
                window.asMacWindow().garbageCollect(skipClosedWindowsCache: true)
                return true
            } else {
                return io.err("Failed to quit '\(window.app.name ?? "Unknown app")'")
            }
        } else {
            if window.close() {
                if !isUnitTest { window.asMacWindow().garbageCollect(skipClosedWindowsCache: true) }
                return true
            } else {
                return io.err("Can't close '\(window.app.name ?? "Unknown app")' window. Probably the window doesn't have a close button")
            }
        }
    }
}
