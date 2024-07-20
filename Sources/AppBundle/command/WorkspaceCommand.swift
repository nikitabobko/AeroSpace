import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
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
        let result = workspace.focusWorkspace()
        state.subject = .focused
        return result
    }

    public static func run(_ state: CommandMutableState, _ name: String) -> Bool { // todo reduce usages
        if let wName = WorkspaceName.parse(name).getOrNil(appendErrorTo: &state.stderr) {
            let args = WorkspaceCmdArgs(rawArgs: [], .direct(WTarget.Direct(wName, autoBackAndForth: false)))
            return WorkspaceCommand(args: args).run(state)
        } else {
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
            .sorted()
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
