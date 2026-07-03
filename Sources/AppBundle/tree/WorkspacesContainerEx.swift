import Common
import Foundation

extension WorkspacesContainer {
    @MainActor func setVisibleWorkspace(_ workspace: Workspace) {
        workspace.bind(to: self, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        if visibleWorkspaceNameOrStale == workspace.name { return }
        prevVisibleWorkspaceName = visibleWorkspaceNameOrStale
        visibleWorkspaceNameOrStale = workspace.name
    }

    @MainActor func getVisibleWorkspaceOrCreate(parent: Monitor) -> Workspace {
        let workspace = children.filterIsInstance(of: Workspace.self).first { $0.name == visibleWorkspaceNameOrStale }?
            .takeIf { $0.parent === self }
        if let workspace { return workspace }

        let stub = getStubWorkspace(forPoint: parent.info.rect.topLeftCorner)
        setVisibleWorkspace(stub)
        return stub
    }
}

// The returned workspace must be invisible and it must belong to the requested monitor
@MainActor func getStubWorkspace(for monitor: MonitorInfo) -> Workspace { // todo revisit this API
    getStubWorkspace(forPoint: monitor.rect.topLeftCorner)
}

@MainActor private func getStubWorkspace(forPoint point: CGPoint) -> Workspace {
    let container = point.monitorApproximation.toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate()
    if let prev = container.prevVisibleWorkspaceName.map({ Workspace.get(byName: $0) }),
       !prev.isVisible && prev.workspaceMonitor.rect.topLeftCorner == point
    {
        return prev
    }
    if let candidate = Workspace.all
        .first(where: { !$0.isVisible && $0.workspaceMonitor.rect.topLeftCorner == point })
    {
        return candidate
    }
    return (1 ... Int.max).lazy
        .map { Workspace.get(byName: String($0)) }
        .first { $0.isEffectivelyEmpty && !$0.isVisible && !config.persistentWorkspaces.contains($0.name) }
        .orDie("Can't create empty workspace")
}
