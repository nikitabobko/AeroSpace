import Foundation
import XCTest
@testable import AeroSpace_Debug

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = Config(
        afterLoginCommand: defaultConfig.afterLoginCommand,
        afterStartupCommand: defaultConfig.afterStartupCommand,
        indentForNestedContainersWithTheSameOrientation: defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: false, // Make layout tests more predictable
        nonEmptyWorkspacesRootContainersLayoutOnStartup: .tiles, // Make layout tests more predictable
        defaultRootContainerLayout: .tiles, // Make default layout predictable
        defaultRootContainerOrientation: .horizontal, // Make default layout predictable
        startAtLogin: defaultConfig.startAtLogin,
        accordionPadding: defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: false, // Make layout tests more predictable
        workspaceToMonitorForceAssignment: [:],

        // Don't create any workspaces for tests
        modes: [mainModeId: Mode(name: nil, bindings: [])],
        onWindowDetected: [],
        preservedWorkspaceNames: []
    )
    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    focusedWindowSourceOfTruth = .defaultSourceOfTruth
    focusedWorkspaceName = mainMonitor.activeWorkspace.name
    Workspace.garbageCollectUnusedWorkspaces()
    check(Workspace.focused.isEffectivelyEmpty)
    check(Workspace.focused === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}

func testParseCommandSucc(_ command: String, _ expected: CommandDescription) {
    let parsed = parseCommand(command)
    switch parsed {
    case .success(let command):
        XCTAssertEqual(command.describe, expected)
    case .failure(let msg):
        XCTFail(msg)
    }
}

func testParseCommandFail(_ command: String, msg expected: String) {
    let parsed = parseCommand(command)
    switch parsed {
    case .success(let command):
        XCTFail("\(command) isn't supposed to be parcelable")
    case .failure(let msg):
        XCTAssertEqual(msg, expected)
    }
}
