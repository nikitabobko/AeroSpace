import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
    let args: WorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode { // todo refactor
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let focusedWs = target.workspace
        let workspaceName: String
        switch args.target.val {
            case .relative(let nextPrev):
                let workspace = getNextPrevWorkspace(
                    current: focusedWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                guard let workspace else { return .fail }
                workspaceName = workspace.name
            case .direct(let name):
                workspaceName = name.raw
                if args.autoBackAndForth && focusedWs.name == workspaceName {
                    return WorkspaceBackAndForthCommand(args: WorkspaceBackAndForthCmdArgs(rawArgs: [])).run(env, io)
                }
        }
        if focusedWs.name == workspaceName {
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err("Workspace '\(workspaceName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code"))
            }
        } else {
            return .from(bool: Workspace.get(byName: workspaceName).focusWorkspace())
        }
    }
}

@MainActor func getNextPrevWorkspace(current: Workspace, isNext: Bool, wrapAround: Bool, stdin: String?, target: LiveFocus) -> Workspace? {
    let stdinWorkspaces: [String] = stdin?.split(separator: "\n").map { String($0).trim() }.filter { !$0.isEmpty } ?? []
    let currentMonitor = current.workspaceMonitor
    let workspaces: [Workspace] = stdin != nil
        ? stdinWorkspaces.map { Workspace.get(byName: $0) }
        : Workspace.all.filter { $0.workspaceMonitor.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }
            .toSet()
            .union([current])
            .sorted()
    let index = workspaces.firstIndex(where: { $0 == target.workspace }) ?? 0
    let workspace: Workspace? = switch wrapAround {
        case true: workspaces.get(wrappingIndex: isNext ? index + 1 : index - 1)
        case false: workspaces.getOrNil(atIndex: isNext ? index + 1 : index - 1)
    }
    return workspace
}
