import Common
import Foundation

extension WorkspacesContainer {
    @MainActor func setVisibleWorkspace(_ workspace: Workspace) -> Bool {
        if !bindWorkspace(workspace) { return false }
        if visibleWorkspaceNameOrStale == workspace.name { return true }
        prevVisibleWorkspaceName = visibleWorkspaceNameOrStale
        visibleWorkspaceNameOrStale = workspace.name
        return true
    }

    @MainActor func getVisibleWorkspaceOrCreate(parent: Monitor) -> Workspace {
        let workspace = children.filterIsInstance(of: Workspace.self).first { $0.name == visibleWorkspaceNameOrStale }?
            .takeIf { $0.parent === self }
        if let workspace { return workspace }

        let stub = getStubWorkspace(forPoint: parent.info.rect.topLeftCorner)
        check(setVisibleWorkspace(stub))
        return stub
    }

    @MainActor func bindWorkspace(_ workspace: Workspace) -> Bool {
        guard let parent = parent as? Monitor else { return false }
        if !isValidAssignment(workspace: workspace, point: parent.info.rect.topLeftCorner) { return false }
        workspace.bind(to: self, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        return true
    }
}

// The returned workspace must be invisible and it must belong to the requested monitor
@MainActor func getStubWorkspace(for monitor: MonitorInfo) -> Workspace { // todo revisit this API
    getStubWorkspace(forPoint: monitor.rect.topLeftCorner)
}

// todo accepting point parameter looks suboptimal
@MainActor private func getStubWorkspace(forPoint point: CGPoint) -> Workspace {
    let container = point.monitorApproximation.toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate()
    if let prev = container.prevVisibleWorkspaceName.map({ Workspace.get(byName: $0) }),
       !prev.isVisible && prev.workspaceMonitorInfo.rect.topLeftCorner == point && prev.forceAssignedMonitorInfo == nil
    {
        return prev
    }
    if let candidate = container.mostRecentChild as? Workspace {
        return candidate
    }
    return (1 ... Int.max).lazy
        .map { Workspace.get(byName: String($0)) }
        .first { $0.isEffectivelyEmpty && !$0.isVisible && !config.persistentWorkspaces.contains($0.name) && $0.forceAssignedMonitorInfo == nil }
        .orDie("Can't create empty workspace")
}

@MainActor private func isValidAssignment(workspace: Workspace, point: CGPoint) -> Bool {
    switch workspace.forceAssignedMonitorInfo {
        case let forceAssigned? where forceAssigned.rect.topLeftCorner != point: false
        default: true
    }
}
