import Foundation
import XCTest
import Common
@testable import AeroSpace_Debug

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = Config(
        afterLoginCommand: defaultConfig.afterLoginCommand,
        afterStartupCommand: defaultConfig.afterStartupCommand,
        indentForNestedContainersWithTheSameOrientation: defaultConfig.indentForNestedContainersWithTheSameOrientation,
        enableNormalizationFlattenContainers: false, // Make layout tests more predictable
        _nonEmptyWorkspacesRootContainersLayoutOnStartup: (), // Make layout tests more predictable
        defaultRootContainerLayout: .tiles, // Make default layout predictable
        defaultRootContainerOrientation: .horizontal, // Make default layout predictable
        startAtLogin: defaultConfig.startAtLogin,
        accordionPadding: defaultConfig.accordionPadding,
        enableNormalizationOppositeOrientationForNestedContainers: false, // Make layout tests more predictable
        execOnWorkspaceChange: [],

        gaps: defaultConfig.gaps,
        workspaceToMonitorForceAssignment: [:],
        // Don't create any workspaces for tests
        modes: [mainModeId: Mode(name: nil, bindings: [:])],
        onWindowDetected: [],
        preservedWorkspaceNames: []
    )
    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    setFocusSourceOfTruth(.ownModel, startup: false)
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
    case .cmd(let command):
        XCTAssertEqual(command.describe, expected)
    case .help:
        error() // todo test help
    case .failure(let msg):
        XCTFail(msg)
    }
}

extension ParsedCmd {
    var errorOrNil: String? {
        if case .failure(let e) = self {
            return e
        } else {
            return nil
        }
    }

    var cmdOrNil: T? {
        if case .cmd(let cmd) = self {
            return cmd
        } else {
            return nil
        }
    }

    var isHelp: Bool {
        if case .help = self {
            return true
        } else {
            return false
        }
    }
}

func testParseCommandFail(_ command: String, msg expected: String) {
    let parsed = parseCommand(command)
    switch parsed {
    case .cmd(let command):
        XCTFail("\(command) isn't supposed to be parcelable")
    case .failure(let msg):
        XCTAssertEqual(msg, expected)
    case .help:
        error() // todo test help
    }
}

extension WTarget.Direct {
    public init(
        _ name: String,
        autoBackAndForth: Bool = false
    ) {
        self.init(.parse(name).getOrNil()!, autoBackAndForth: autoBackAndForth)
    }
}
