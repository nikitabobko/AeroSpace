import Common

extension Monitor {
    @MainActor func getWorkspacesContainerOrCreate() -> WorkspacesContainer {
        let containers = children.filterIsInstance(of: WorkspacesContainer.self)
        return switch containers.count {
            case 0: WorkspacesContainer(parent: self)
            case 1: containers.singleOrNil().orDie()
            default: dieT("Workspace must contain zero or one MacosFullscreenWindowsContainer")
        }
    }
}
