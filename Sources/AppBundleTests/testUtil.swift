@testable import AppBundle
import AppKit
import Common
import Foundation
import HotKey
import Testing

let projectRoot: URL = {
    var url = URL(filePath: #filePath).absoluteURL
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    return url
}()

var name: String { Test.current.orDie().name }

extension Trait where Self == SerializedGloballyTrait {
    // todo: make tests parallel
    static var serializedGlobally: Self { SerializedGloballyTrait() }
}

struct SerializedGloballyTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    @concurrent func provideScope(for test: Test, testCase: Test.Case?, performing function: @concurrent @Sendable () async throws -> Void) async throws {
        try await runExclusively(function)
    }
}

@MainActor private var previousTestCompletion: Task<Void, Never>? = nil

// todo: that's a cool serialization trick AI came up with.
// - I need to think if I need to serialize refreshing sessions like this
// - I also need to understand how it relates to AwaitableOneTimeLatch
@MainActor private func runExclusively(_ body: @concurrent @Sendable () async throws -> Void) async throws {
    let previous = previousTestCompletion
    let (completion, completionContinuation) = AsyncStream.makeStream(of: Never.self)
    previousTestCompletion = Task.startUnstructured { for await _ in completion {} }
    defer { completionContinuation.finish() }
    await previous?.value
    try await body()
}

@MainActor
func setUpWorkspacesForTests() {
    config = defaultConfig
    configUrl = defaultConfigUrl
    config.enableNormalizationFlattenContainers = false // Make layout tests more predictable
    config.enableNormalizationOppositeOrientationForNestedContainers = false // Make layout tests more predictable
    config.defaultRootContainerOrientation = .horizontal // Make default layout predictable

    // Don't create any bindings and workspaces for tests
    config.modes = [mainModeId: Mode(bindings: [:])]
    config.persistentWorkspaces = []

    for workspace in Workspace.all {
        for child in workspace.children {
            child.unbindFromParent()
        }
    }
    check(Workspace.get(byName: "setUpWorkspacesForTests").focusWorkspace())
    Workspace.garbageCollectUnusedWorkspaces()
    check(globalFocus.workspace.isEffectivelyEmpty)
    check(globalFocus.workspace === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))
    check(mainMonitorInfo.setVisibleWorkspace(globalFocus.workspace))

    TestApp.shared.focusedWindow = nil
    TestApp.shared.windows = []

    global_layoutForNextDetectedWindow = nil
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

func testParseCommandFail(_ command: String, msg expectedMsg: String, exitCode expectedExitCode: Int32, sourceLocation: SourceLocation = #_sourceLocation) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(let command): Issue.record(Comment(rawValue: "\(command) isn't supposed to be parcelable"))
        case .help: die() // todo test help
        case .failure(let failure):
            assertEquals(failure, .init(expectedMsg, expectedExitCode), sourceLocation: sourceLocation)
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
