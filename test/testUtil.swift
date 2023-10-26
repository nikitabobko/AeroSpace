import Foundation
@testable import AeroSpace_Debug

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = Config(
        afterLoginCommand: defaultConfig.afterLoginCommand,
        afterStartupCommand: defaultConfig.afterStartupCommand,
        indentForNestedContainersWithTheSameOrientation: defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: false, // Make layout tests more predictable
        floatingWindowsOnTop: defaultConfig.floatingWindowsOnTop,
        mainLayout: .h_list, // Make default layout predictable
        startAtLogin: defaultConfig.startAtLogin,
        accordionPadding: defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: false, // Make layout tests more predictable

        // Don't create any workspaces for tests
        modes: [mainModeId: Mode(name: nil, bindings: [])],
        preservedWorkspaceNames: []
    )
    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    focusedWorkspaceSourceOfTruth = .defaultSourceOfTruth
    focusedWorkspaceName = mainMonitor.activeWorkspace.name
    Workspace.garbageCollectUnusedWorkspaces()
    precondition(Workspace.focused.isEffectivelyEmpty)
    precondition(Workspace.focused === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}
