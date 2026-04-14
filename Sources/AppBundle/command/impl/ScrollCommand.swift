import AppKit
import Common

struct ScrollCommand: Command {
    let args: ScrollCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        let root = focus.workspace.rootTilingContainer
        guard root.layout == .scrolling else {
            return .fail(io.err("scroll command only works when the workspace root container uses the scrolling layout"))
        }
        let direction: CardinalDirection = switch args.direction.val {
            case .left: .left
            case .right: .right
        }
        root.clampScrollingIndex()
        guard let target = root.scroll(in: direction) else { return .succ }
        return .from(bool: target.focusWindow())
    }
}
