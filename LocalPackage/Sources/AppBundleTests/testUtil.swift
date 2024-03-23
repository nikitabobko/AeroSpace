import Foundation
import XCTest
import Common
@testable import AppBundle

let projectRoot: URL = URL(filePath: #file).appending(component: "../..").standardized

func setUpWorkspacesForTests() {
    config = defaultConfig
    config.enableNormalizationFlattenContainers = false // Make layout tests more predictable
    config.enableNormalizationOppositeOrientationForNestedContainers = false // Make layout tests more predictable
    config.defaultRootContainerOrientation = .horizontal // Make default layout predictable

    // Don't create any bindings and workspaces for tests
    config.modes = [mainModeId: Mode(name: nil, bindings: [:])]
    config.preservedWorkspaceNames = []

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
    check(mainMonitor.setActiveWorkspace(Workspace.focused))

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
