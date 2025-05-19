import Common
import Foundation

// import HotKey // REMOVE
import XCTest

@testable import AppBundle

let projectRoot: URL = {
    var url = URL(filePath: #filePath).absoluteURL
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    return url
}()

@MainActor
func setUpWorkspacesForTests() {
    config = defaultConfig
    configUrl = defaultConfigUrl
    config.enableNormalizationFlattenContainers = false  // Make layout tests more predictable
    config.enableNormalizationOppositeOrientationForNestedContainers = false  // Make layout tests more predictable
    config.defaultRootContainerOrientation = .horizontal  // Make default layout predictable

    // Don't create any bindings and workspaces for tests
    config.modes = [mainModeId: Mode(name: nil, bindings: [:])]
    config.preservedWorkspaceNames = []

    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    check(Workspace.get(byName: "setUpWorkspacesForTests").focusWorkspace())
    Workspace.garbageCollectUnusedWorkspaces()
    check(focus.workspace.isEffectivelyEmpty)
    check(
        focus.workspace === Workspace.all.singleOrNil(),
        Workspace.all.map(\.description).joined(separator: ", "))
    check(mainMonitor.setActiveWorkspace(focus.workspace))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}

func testParseCommandSucc(_ command: String, _ expected: any CmdArgs) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(let command):
            XCTAssertTrue(
                command.args.equals(expected), "actual: \(command.args) expected: \(expected)")
        case .help: die()  // todo test help
        case .failure(let msg): XCTFail(msg)
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
        case .cmd(let command): XCTFail("\(command) isn't supposed to be parcelable")
        case .failure(let msg): assertEquals(msg, expected)
        case .help: die()  // todo test help
    }
}

extension WorkspaceCmdArgs {
    init(target: WorkspaceTarget, autoBackAndForth: Bool? = nil, wrapAround: Bool? = nil) {
        self = WorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(target)
        self._autoBackAndForth = autoBackAndForth
        self._wrapAround = wrapAround
    }
}

extension MoveNodeToWorkspaceCmdArgs {
    init(target: WorkspaceTarget, wrapAround: Bool? = nil) {
        self = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(target)
        self._wrapAround = wrapAround
    }

    init(workspace: String) {
        self = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(.direct(.parse(workspace).getOrDie()))
    }
}

extension HotkeyBinding {
    // Convenience init for tests using exact modifiers and UInt16 keycode
    init(
        exactModifiers: Set<PhysicalModifierKey>,
        keyCode: UInt16,
        commands: [any Command],
        // descriptionWithKeyNotation is the raw string from config,
        // for tests, we either pass it or construct a similar representation.
        _ descriptionForTests: String? = nil
    ) {
        let constructedDescription =
            exactModifiers.isEmpty
                ? virtualKeyCodeToString(keyCode)
                : exactModifiers.toString() + "-" + virtualKeyCodeToString(keyCode)

        // The main HotkeyBinding init takes descriptionWithKeyNotation, which is the raw binding string.
        // For tests, if descriptionForTests is nil, we use the constructed one.
        // This matches how descriptionWithKeyCode is generated.
        self.init(
            exactModifiers: exactModifiers,
            genericModifiers: [],
            keyCode: keyCode,
            commands: commands,
            descriptionWithKeyNotation: descriptionForTests ?? constructedDescription
        )
    }
}
