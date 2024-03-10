import Common
import Foundation

struct WorkspaceCommand : Command {
    let args: WorkspaceCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        let workspaceName: String
        switch args.target {
        case .relative(let relative):
            guard let workspace = getNextPrevWorkspace(current: state.subject.workspace, relative: relative, stdin: stdin) else { return false }
            workspaceName = workspace.name
        case .direct(let direct):
            workspaceName = direct.name.raw
            if direct.autoBackAndForth && state.subject.workspace.name == workspaceName {
                return WorkspaceBackAndForthCommand().run(state)
            }
        }
        let workspace = Workspace.get(byName: workspaceName)
        // todo drop anyLeafWindowRecursive. It must not be necessary
        if let window = workspace.mostRecentWindow ?? workspace.anyLeafWindowRecursive { // switch to not empty workspace
            state.subject = .window(window)
        } else { // switch to empty workspace
            check(workspace.isEffectivelyEmpty)
            state.subject = .emptyWorkspace(workspaceName)
        }
        check(workspace.workspaceMonitor.setActiveWorkspace(workspace))
        focusedWorkspaceName = workspace.name
        return true
    }

    public static func run(_ state: CommandMutableState, _ name: String) -> Bool {
        if let wName = WorkspaceName.parse(name).getOrNil(appendErrorTo: &state.stderr) {
            let args = WorkspaceCmdArgs(.direct(WTarget.Direct(wName, autoBackAndForth: false)))
            return WorkspaceCommand(args: args).run(state)
        } else {
            state.stderr.append("Prohibited or reserved workspace name \(name)")
            return false
        }
    }
}

func getNextPrevWorkspace(current: Workspace, relative: WTarget.Relative, stdin: String) -> Workspace? {
    let stdinWorkspaces: [String] = stdin.split(separator: "\n").map { String($0).trim() }.filter { !$0.isEmpty }
    let currentMonitor = current.workspaceMonitor
    let workspaces: [Workspace] = stdinWorkspaces.isEmpty
        ? Workspace.all.filter { $0.workspaceMonitor.rect.topLeftCorner == currentMonitor.rect.topLeftCorner }
            .toSet()
            .union([current])
            .sortedBy { $0.name }
        : stdinWorkspaces.map { Workspace.get(byName: $0) }
    let index = workspaces.firstIndex(where: { $0 == Workspace.focused }) ?? 0
    let workspace: Workspace?
    if relative.wrapAround {
        workspace = workspaces.get(wrappingIndex: relative.isNext ? index + 1 : index - 1)
    } else {
        workspace = workspaces.getOrNil(atIndex: relative.isNext ? index + 1 : index - 1)
    }
    return workspace
}
