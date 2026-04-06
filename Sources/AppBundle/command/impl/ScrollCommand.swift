import AppKit
import Common

struct ScrollCommand: Command {
    let args: ScrollCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let root = focus.workspace.rootTilingContainer
        guard root.layout == .scrolling else {
            return io.err("scroll command only works when the workspace root container uses the scrolling layout")
        }
        let direction: CardinalDirection = switch args.direction.val {
            case .left: .left
            case .right: .right
        }
        root.clampScrollingIndex()
        guard let target = root.scroll(in: direction) else { return true }
        return target.focusWindow()
    }
}
