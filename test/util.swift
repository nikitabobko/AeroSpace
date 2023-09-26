import Foundation
@testable import AeroSpace_Debug

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = Config(
        afterStartupCommand: defaultConfig.afterStartupCommand,
        usePaddingForNestedContainersWithTheSameOrientation: defaultConfig.usePaddingForNestedContainersWithTheSameOrientation,
        autoFlattenContainers: false, // Make layout tests more predictable
        floatingWindowsOnTop: defaultConfig.floatingWindowsOnTop,
        mainLayout: .h_list, // Make default layout predictable
        focusWrapping: defaultConfig.focusWrapping,
        debugAllWindowsAreFloating: defaultConfig.debugAllWindowsAreFloating,

        // Don't create any workspaces for tests
        modes: [mainModeId: Mode(name: nil, bindings: [])],
        workspaceNames: []
    )
    currentEmptyWorkspace = Workspace.get(byName: "EMPTY WORKSPACE FOR TESTS")
    TrayMenuModel.shared.focusedWorkspaceTrayText = currentEmptyWorkspace.name
    precondition(Workspace.all.singleOrNil() === currentEmptyWorkspace)
    precondition(currentEmptyWorkspace.isEffectivelyEmpty)

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}

func tearDownWorkspacesForTests() {
    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
}

extension TreeNode {
    @discardableResult
    func apply(_ block: (TreeNode) -> Void) -> Self {
        block(self)
        return self
    }
}
