@testable import AppBundle
import Common
import Foundation
import HotKey
import XCTest

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
    config.enableNormalizationFlattenContainers = false // Make layout tests more predictable
    config.enableNormalizationOppositeOrientationForNestedContainers = false // Make layout tests more predictable
    config.defaultRootContainerOrientation = .horizontal // Make default layout predictable
    config.onFocusedMonitorChanged = .empty // Default config moves the mouse. Don't move the real mouse in tests

    // Don't create any bindings and workspaces for tests
    config.modes = [mainModeId: Mode(bindings: [:])]
    config.persistentWorkspaces = []

    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    monitorInfosForTests = [testMonitorInfo]
    rearrangeWorkspacesOnMonitors()
    check(Workspace.get(byName: "setUpWorkspacesForTests").focusWorkspace())
    check(mainMonitorInfo.setActiveWorkspace(focus.workspace))
    Workspace.garbageCollectUnusedWorkspaces()
    check(focus.workspace.isEffectivelyEmpty)
    check(focus.workspace === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []
}

/// Replaces the single test monitor with monitors of the given rects. The monitor at (0, 0) is the main monitor.
/// Like on real monitors reconfiguration, visible workspaces stay on the closest monitors (e.g. the main monitor keeps its
/// workspace), and the rest of the monitors get empty workspaces
@MainActor
@discardableResult
func setUpMonitorsForTests(_ rects: [Rect]) -> [MonitorInfo] {
    check(rects.count(where: { $0.topLeftCorner == .zero }) == 1, "Exactly one (main) monitor must be at (0, 0). rects: \(rects)")
    monitorInfosForTests = rects.enumerated().map { (index, rect) in
        MonitorInfoImpl(
            monitorAppKitNsScreenScreensId: index + 1,
            name: "Test Monitor \(index + 1)",
            rect: rect,
            visibleRect: rect,
            isMain: rect.topLeftCorner == .zero,
        )
    }
    rearrangeWorkspacesOnMonitors()
    return monitorInfosForTests
}

extension ParsedCmd {
    var errorOrNil: String? {
        return switch self {
            case .failure(let e): e.msg
            case .cmd, .help: nil
        }
    }

    var cmdOrDie: T { cmdOrNil ?? dieT("\(self)") }
}

func testParseCommandFail(_ command: String, msg expectedMsg: String, exitCode expectedExitCode: Int32, file: StaticString = #filePath, line: UInt = #line) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(let command): XCTFail("\(command) isn't supposed to be parcelable")
        case .help: die() // todo test help
        case .failure(let failure):
            assertEquals(failure, .init(expectedMsg, expectedExitCode), file: file, line: line)
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
    init(_ modifiers: NSEvent.ModifierFlags, _ keyCode: Key, _ commands: Shell<any Command>) {
        let descriptionWithKeyNotation = modifiers.isEmpty
            ? keyCode.toString()
            : modifiers.toString() + "-" + keyCode.toString()
        self.init(modifiers, keyCode, commands, descriptionWithKeyNotation: descriptionWithKeyNotation)
    }
}

extension FocusCommand {
    static func new(direction: CardinalDirection) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .direction(direction)))
    }
}

func parseCommand(_ raw: String) -> ParsedCmd<Shell<any Command>> { parseCommand(raw, allowExecAndForget: true, allowEval: true) }
