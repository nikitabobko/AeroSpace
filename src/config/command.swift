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
        for mode in config.modes {
            for binding in mode.bindings {
                if mode.id == idToActivate {
                    binding.activate()
                } else {
                    binding.deactivate()
                }
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
