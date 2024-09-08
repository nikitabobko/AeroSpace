import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
    let args: WorkspaceCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let workspaceName: String
        switch args.target.val {
            case .relative(let isNext):
                guard let workspace = getNextPrevWorkspace(current: state.subject.workspace, isNext: isNext, wrapAround: args.wrapAround, stdin: stdin) else { return false }
                workspaceName = workspace.name
            case .direct(let name):
                workspaceName = name.raw
                if args.autoBackAndForth && state.subject.workspace.name == workspaceName {
                    return WorkspaceBackAndForthCommand().run(state)
                }
        }
        let workspace = Workspace.get(byName: workspaceName)
        let result = workspace.focusWorkspace()
        state.subject = .focused
        return result
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
