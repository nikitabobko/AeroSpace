import Foundation

protocol Command {
    func run()
}

struct ChainedCommand: Command {
    let subCommands: [Command]

    func run() {
        for command in subCommands {
            command.run()
        }
    }
}

enum NoOpCommand: Command {
    case instance

    func run() {} // It does nothing
}

struct WorkspaceCommand : Command {
    let workspaceName: String

    func run() {
        switchToWorkspace(Workspace.get(byName: workspaceName))
    }
}

struct ModeCommand: Command {
    let idToActivate: String

    func run() {
        for (modeId, mode) in config.modes {
            if modeId == idToActivate {
                mode.activate()
            } else {
                mode.deactivate()
            }
        }
    }
}

struct BashCommand: Command {
    let bashCommand: String

    func run() {
        do {
            try Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
        } catch {
        }
    }
}

/// Syntax:
/// layout (main|h_accordion|v_accordion|h_list|v_list|floating|tiling)...
struct LayoutCommand: Command {
    let toggleTo: [Layout]
    enum Layout {
        case main
        case h_accordion
        case v_accordion
        case h_list
        case v_list
        case floating
    }

    func run() {
        // todo
    }
}

struct FocusCommand: Command {
    let direction: Direction

    enum Direction {
        case up
        case down
        case left
        case right

        case parent
        case child
        case floating
        case tiling
        case toggle_tiling_floating
    }

    func run() {
        // todo
    }
}

struct ReloadConfigCommand: Command {
    func run() {
        reloadConfig()
        refresh()
    }
}
