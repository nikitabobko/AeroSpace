import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
    let args: WorkspaceCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool { // todo refactor
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let focusedWs = target.workspace
        let workspaceName: String
        switch args.target.val {
            case .relative(let nextPrev):
                let stdin = io.readStdin()
                let useStdin = args.stdin
                if !stdin.isEmpty && !useStdin {
                    return io.err("ERROR: Implicit stdin is detected (stdin is not TTY). Implicit stdin was forbidden in AeroSpace v0.20.0.\nPlease supply '--stdin' flag to make stdin explicit and preserve old AeroSpace behavior.\nBreaking change issue: https://github.com/nikitabobko/AeroSpace/issues/1683")
                }
                let workspace = getNextPrevWorkspace(
                    current: focusedWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: stdin,
                    useStdin: useStdin,
                    target: target,
                )
                guard let workspace else { return false }
                workspaceName = workspace.name
            case .direct(let name):
                workspaceName = name.raw
                if args.autoBackAndForth && focusedWs.name == workspaceName {
                    return WorkspaceBackAndForthCommand(args: WorkspaceBackAndForthCmdArgs(rawArgs: [])).run(env, io)
                }
        }
        if focusedWs.name == workspaceName {
            io.err("Workspace '\(workspaceName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        } else {
            return Workspace.get(byName: workspaceName).focusWorkspace()
        }
    }
}

@MainActor func getNextPrevWorkspace(current: Workspace, isNext: Bool, wrapAround: Bool, stdin: String, useStdin: Bool, target: LiveFocus) -> Workspace? {
    let stdinWorkspaces: [String] = stdin.split(separator: "\n").map { String($0).trim() }.filter { !$0.isEmpty }
    let currentMonitor = current.workspaceMonitor
    let workspaces: [Workspace] = useStdin
        ? stdinWorkspaces.map { Workspace.get(byName: $0) }
        : Workspace.all.filter { $0.workspaceMonitor.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }
            .toSet()
            .union([current])
            .sorted()
    let index = workspaces.firstIndex(where: { $0 == target.workspace }) ?? 0
    let workspace: Workspace? = if wrapAround {
        workspaces.get(wrappingIndex: isNext ? index + 1 : index - 1)
    } else {
        workspaces.getOrNil(atIndex: isNext ? index + 1 : index - 1)
    }
    return workspace
}
