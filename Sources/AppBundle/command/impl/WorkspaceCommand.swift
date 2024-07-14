import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
    let args: WorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool { // todo refactor
        check(Thread.current.isMainThread)
        guard let subject = args.resolveFocusOrReportError(env, io)?.workspace else { return false }
        let workspaceName: String
        switch args.target.val {
            case .relative(let isNext):
                let workspace = getNextPrevWorkspace(current: subject, isNext: isNext, wrapAround: args.wrapAround, stdin: io.readStdin())
                guard let workspace else { return false }
                workspaceName = workspace.name
            case .direct(let name):
                workspaceName = name.raw
                if args.autoBackAndForth && subject.name == workspaceName {
                    return WorkspaceBackAndForthCommand().run(env, io)
                }
        }
        if subject.name == workspaceName {
            io.err("Workspace '\(workspaceName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        } else {
            return Workspace.get(byName: workspaceName).focusWorkspace()
        }
    }
}

func getNextPrevWorkspace(current: Workspace, isNext: Bool, wrapAround: Bool, stdin: String) -> Workspace? {
    let stdinWorkspaces: [String] = stdin.split(separator: "\n").map { String($0).trim() }.filter { !$0.isEmpty }
    let currentMonitor = current.workspaceMonitor
    let workspaces: [Workspace] = stdinWorkspaces.isEmpty
        ? Workspace.all.filter { $0.workspaceMonitor.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }
            .toSet()
            .union([current])
            .sorted()
        : stdinWorkspaces.map { Workspace.get(byName: $0) }
    let index = workspaces.firstIndex(where: { $0 == focus.workspace }) ?? 0
    let workspace: Workspace? = if wrapAround {
        workspaces.get(wrappingIndex: isNext ? index + 1 : index - 1)
    } else {
        workspaces.getOrNil(atIndex: isNext ? index + 1 : index - 1)
    }
    return workspace
}
