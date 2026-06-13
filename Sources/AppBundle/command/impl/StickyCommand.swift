import AppKit
import Common

struct StickyCommand: Command {
    let args: StickyCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isSticky
        }
        if newState == window.isSticky {
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err((newState ? "Already sticky. " : "Already not sticky. ") +
                            "Tip: use --fail-if-noop to exit with non-zero code"))
            }
        }
        window.isSticky = newState
        if newState && !window.isFloating, let workspace = window.nodeWorkspace {
            if window.lastFloatingSize == nil {
                window.lastFloatingSize = try await window.getAxSize()
            }
            window.bindAsFloatingWindow(to: workspace)
        }
        window.markAsMostRecentChild()
        return .succ
    }
}
