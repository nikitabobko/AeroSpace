import Common

extension Window {
    @MainActor
    var visualWorkspaceForWindow: Workspace? {
        stickyWorkspaceOnActiveMonitor ?? nodeWorkspace ?? nodeMonitor?.activeWorkspace
    }

    @MainActor
    func isVisuallyOn(workspace: Workspace) -> Bool {
        visualWorkspaceForWindow == workspace
    }

    @MainActor
    var shouldStayVisibleWhenOwningWorkspaceIsHidden: Bool {
        stickyWorkspaceOnActiveMonitor != nil
    }

    @MainActor
    private var stickyWorkspaceOnActiveMonitor: Workspace? {
        guard isSticky,
              isManagedByAeroSpaceWorkspaceVisibility,
              nodeWorkspace?.isVisible != true
        else { return nil }
        return nodeMonitor?.activeWorkspace
    }

    @MainActor
    private var isManagedByAeroSpaceWorkspaceVisibility: Bool {
        guard let parent else { return false }
        return switch getChildParentRelation(child: self, parent: parent) {
            case .floatingWindow, .tiling: true
            case .rootTilingContainer, .shimContainerRelation,
                 .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow,
                 .macosNativeMinimizedWindow, .macosPopupWindow:
                false
        }
    }
}

@MainActor
func windowsVisuallyOnWorkspace(_ workspace: Workspace) -> [Window] {
    Workspace.all
        .flatMap(\.allLeafWindowsRecursive)
        .filter { $0.isVisuallyOn(workspace: workspace) }
}

@MainActor
func windowsInOrVisuallyOnWorkspace(_ workspace: Workspace) -> [Window] {
    Array((workspace.allLeafWindowsRecursive + windowsVisuallyOnWorkspace(workspace)).toOrderedSet())
}
