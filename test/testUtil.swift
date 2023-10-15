import Foundation
@testable import AeroSpace_Debug

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = Config(
        afterStartupCommand: defaultConfig.afterStartupCommand,
        afterLoginCommand: defaultConfig.afterLoginCommand,
        usePaddingForNestedContainersWithTheSameOrientation: defaultConfig.usePaddingForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: false, // Make layout tests more predictable
        floatingWindowsOnTop: defaultConfig.floatingWindowsOnTop,
        mainLayout: .h_list, // Make default layout predictable
        focusWrapping: defaultConfig.focusWrapping,
        debugAllWindowsAreFloating: defaultConfig.debugAllWindowsAreFloating,
        startAtLogin: defaultConfig.startAtLogin,
        accordionPadding: defaultConfig.accordionPadding,

        // Don't create any workspaces for tests
        modes: [mainModeId: Mode(name: nil, bindings: [])],
        preservedWorkspaceNames: []
    )
    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    focusedWorkspaceName = mainMonitor.activeWorkspace.name
    Workspace.garbageCollectUnusedWorkspaces()
    precondition(Workspace.focused.isEffectivelyEmpty)
    precondition(Workspace.focused === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}
