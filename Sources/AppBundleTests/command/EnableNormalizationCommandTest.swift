@testable import AppBundle
import Common
import XCTest

@MainActor
final class EnableNormalizationCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        let command = parseCommand("enable-normalization flatten-containers on").cmdOrNil?.flatten().singleOrNil()
        XCTAssertTrue(command is EnableNormalizationCommand)
        let args = (command as! EnableNormalizationCommand).args
        assertEquals(args.kind.val, .flattenContainers)
        assertEquals(args.targetState.val, .on)
        assertEquals(args.failIfNoop, false)
        XCTAssertNil(args.workspaceName)

        let command2 = parseCommand("enable-normalization --workspace foo --fail-if-noop opposite-orientation-for-nested-containers off").cmdOrNil?.flatten().singleOrNil()
        XCTAssertTrue(command2 is EnableNormalizationCommand)
        let args2 = (command2 as! EnableNormalizationCommand).args
        assertEquals(args2.kind.val, .oppositeOrientationForNestedContainers)
        assertEquals(args2.targetState.val, .off)
        assertEquals(args2.failIfNoop, true)
        assertEquals(args2.workspaceName?.raw, "foo")
    }

    func testParseFailIfNoopIncompatibleWithToggleAndReset() {
        assertEquals(
            parseCommand("enable-normalization flatten-containers toggle --fail-if-noop").errorOrNil,
            "--fail-if-noop is incompatible with 'toggle' or 'reset' arguments",
        )
        assertEquals(
            parseCommand("enable-normalization flatten-containers reset --fail-if-noop").errorOrNil,
            "--fail-if-noop is incompatible with 'toggle' or 'reset' arguments",
        )
    }

    func testParseInvalidKind() {
        let error = parseCommand("enable-normalization bogus on").errorOrNil
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("bogus") == true, "error must name the unparsable argument: \(error ?? "nil")")
        XCTAssertTrue(error?.contains("flatten-containers|opposite-orientation-for-nested-containers") == true, "error must list the possible values: \(error ?? "nil")")
    }

    func testParseMissingArgs() {
        let error = parseCommand("enable-normalization").errorOrNil
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("flatten-containers|opposite-orientation-for-nested-containers") == true, "error must mention the mandatory <kind> placeholder: \(error ?? "nil")")
    }

    func testOverride_on_takesPrecedenceOverGlobalOff() {
        config.enableNormalizationOppositeOrientationForNestedContainers = false
        let workspace = Workspace.get(byName: name)
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true

        XCTAssertTrue(workspace.isNormalizationEnabled(.oppositeOrientationForNestedContainers))
    }

    func testOverride_off_takesPrecedenceOverGlobalOn() {
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = Workspace.get(byName: name)
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = false

        XCTAssertFalse(workspace.isNormalizationEnabled(.oppositeOrientationForNestedContainers))
    }

    func testOverride_isPerWorkspace() {
        config.enableNormalizationOppositeOrientationForNestedContainers = false
        let a = Workspace.get(byName: "ws-A-\(name)")
        let b = Workspace.get(byName: "ws-B-\(name)")
        a.normalizationOverride[.oppositeOrientationForNestedContainers] = true

        XCTAssertTrue(a.isNormalizationEnabled(.oppositeOrientationForNestedContainers))
        XCTAssertFalse(b.isNormalizationEnabled(.oppositeOrientationForNestedContainers))
    }

    func testOverride_appliedAtRefreshTime() {
        config.enableNormalizationOppositeOrientationForNestedContainers = false
        let workspace = Workspace.get(byName: name)
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }

        workspace.normalizeContainers()

        // opposite-orientation ran on this workspace despite the global flag being off.
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([.window(2), .window(3)]),
            ]),
        )
    }

    /// The override lives only as long as the workspace: garbage collection of an
    /// empty invisible workspace destroys the override together with the workspace.
    func testOverride_diesWithWorkspaceGC() {
        config.enableNormalizationOppositeOrientationForNestedContainers = false
        let doomedName = "ws-gc-doomed"
        Workspace.get(byName: doomedName).normalizationOverride[.oppositeOrientationForNestedContainers] = true

        Workspace.garbageCollectUnusedWorkspaces()
        XCTAssertFalse(Workspace.all.contains { $0.name == doomedName }, "precondition: empty invisible workspace must be garbage-collected")

        let revived = Workspace.get(byName: doomedName)
        XCTAssertNil(revived.normalizationOverride[.oppositeOrientationForNestedContainers])
        XCTAssertFalse(revived.isNormalizationEnabled(.oppositeOrientationForNestedContainers))
    }

    func testChangeOrientation_overrideOn_cascadesToAncestors() {
        // Global opposite-orientation normalization is off via setUpWorkspacesForTests.
        let workspace = focus.workspace
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
            }
        }
        let nested = root.children[1] as! TilingContainer

        nested.changeOrientation(.h)

        assertEquals(root.layoutDescription, .v_tiles([
            .window(1),
            .h_tiles([.window(2)]),
        ]))
    }

    func testChangeOrientation_overrideOff_globalOn_doesNotCascade() {
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let workspace = focus.workspace
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = false
        let root = workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
            }
        }
        let nested = root.children[1] as! TilingContainer

        nested.changeOrientation(.h)

        assertEquals(root.layoutDescription, .h_tiles([
            .window(1),
            .h_tiles([.window(2)]),
        ]))
    }

    func testCommand_on_setsOverride() async {
        let workspace = focus.workspace
        _ = await parseCommand("enable-normalization opposite-orientation-for-nested-containers on").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)

        assertEquals(workspace.normalizationOverride[.oppositeOrientationForNestedContainers], true)
    }

    func testCommand_off_setsOverride() async {
        let workspace = focus.workspace
        _ = await parseCommand("enable-normalization opposite-orientation-for-nested-containers off").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)

        assertEquals(workspace.normalizationOverride[.oppositeOrientationForNestedContainers], false)
    }

    func testCommand_toggle_flipsEffectiveValue() async {
        config.enableNormalizationOppositeOrientationForNestedContainers = false
        let workspace = focus.workspace

        _ = await parseCommand("enable-normalization opposite-orientation-for-nested-containers toggle").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)
        assertEquals(workspace.normalizationOverride[.oppositeOrientationForNestedContainers], true)

        _ = await parseCommand("enable-normalization opposite-orientation-for-nested-containers toggle").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)
        assertEquals(workspace.normalizationOverride[.oppositeOrientationForNestedContainers], false)
    }

    func testCommand_reset_clearsOverride() async {
        let workspace = focus.workspace
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true

        _ = await parseCommand("enable-normalization opposite-orientation-for-nested-containers reset").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)

        XCTAssertNil(workspace.normalizationOverride[.oppositeOrientationForNestedContainers])
    }

    /// Repeating 'on' when the override is already set is a noop: without
    /// --fail-if-noop the command reports it on stderr and succeeds, following
    /// the same convention as the 'enable' and 'workspace' commands.
    func testCommand_on_noop_succeedsWithoutFailIfNoop() async {
        let workspace = focus.workspace
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true

        let result = await parseCommand("enable-normalization opposite-orientation-for-nested-containers on").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        XCTAssertFalse(result.stderr.isEmpty, "noop must be reported on stderr")
        assertEquals(workspace.normalizationOverride[.oppositeOrientationForNestedContainers], true)
    }

    func testCommand_on_noop_failsWithFailIfNoop() async {
        let workspace = focus.workspace
        workspace.normalizationOverride[.oppositeOrientationForNestedContainers] = true

        let result = await parseCommand("enable-normalization opposite-orientation-for-nested-containers on --fail-if-noop").cmdOrDie
            .run(.defaultEnv.withWorkspaceName(workspace.name), .emptyStdin)

        assertEquals(result.exitCode.rawValue, 2)
    }

    /// '--workspace <name>' targets a non-focused workspace without leaking the
    /// override onto the focused one. Without the flag the command would fall
    /// through to `focus.workspace`.
    func testCommand_withWorkspaceFlag_targetsNonFocusedWorkspace() async {
        // Hardcoded simple name so WorkspaceName.parse accepts it; XCTest's
        // 'name' property contains brackets that are not legal in workspace
        // names.
        let otherName = "ws-flag-target"
        let focused = focus.workspace
        let other = Workspace.get(byName: otherName)
        assertNotEquals(focused.name, other.name)
        // A window keeps 'other' out of the doomed-workspace refusal: overrides
        // can only be set on workspaces that survive garbage collection.
        TestWindow.new(id: 1, parent: other.rootTilingContainer)

        _ = await parseCommand("enable-normalization --workspace \(otherName) opposite-orientation-for-nested-containers off").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        assertEquals(other.normalizationOverride[.oppositeOrientationForNestedContainers], false)
        XCTAssertNil(focused.normalizationOverride[.oppositeOrientationForNestedContainers], "override must not leak to the focused workspace")
    }

    /// Setting an override on a workspace that garbage collection is about to
    /// destroy would silently have no effect, so the command refuses instead.
    func testCommand_onEmptyInvisibleWorkspace_fails() async {
        let doomedName = "ws-doomed"

        let result = await parseCommand("enable-normalization --workspace \(doomedName) flatten-containers on").cmdOrDie
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 2)
        XCTAssertFalse(result.stderr.isEmpty, "refusal must be explained on stderr")
        XCTAssertNil(Workspace.get(byName: doomedName).normalizationOverride[.flattenContainers])
    }
}
