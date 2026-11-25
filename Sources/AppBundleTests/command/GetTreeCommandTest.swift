@testable import AppBundle
import Common
import XCTest

@MainActor
final class GetTreeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
            TestWindow.new(id: 4, parent: $0.floatingWindowsContainer) // floating
        }
        assertEquals(workspace.focusWorkspace(), true)
        // Drop the workspace created by setUpWorkspacesForTests, to keep the tree minimal
        Workspace.garbageCollectUnusedWorkspaces()
        assertEquals(Workspace.all.count, 1)

        let expected = JSONEncoder.aeroSpaceDefault.encodeToString(rootJson([
            monitorJson([
                .dict([
                    "type": .string("workspace"),
                    "name": .string(name),
                    "layout": .string("tiles"),
                    "orientation": .string("horizontal"),
                    "focused": .bool(false), // focusWorkspace() focuses the most recently bound window (id 4)
                    "visible": .bool(true),
                    "nodes": .array([
                        windowJson(1),
                        .dict([
                            "type": .string("container"),
                            "layout": .string("tiles"),
                            "orientation": .string("vertical"),
                            "nodes": .array([
                                windowJson(2),
                                windowJson(3),
                            ]),
                        ]),
                    ]),
                    "floating-windows": .array([
                        windowJson(4, focused: true),
                    ]),
                ]),
            ]),
        ]))

        let result = await parseCommand("get_tree").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [expected])
    }

    func testEmptyWorkspace() async {
        let workspace = Workspace.get(byName: name)
        assertEquals(workspace.focusWorkspace(), true)
        Workspace.garbageCollectUnusedWorkspaces()
        assertEquals(Workspace.all.count, 1)

        let expected = JSONEncoder.aeroSpaceDefault.encodeToString(rootJson([
            monitorJson([
                .dict([
                    "type": .string("workspace"),
                    "name": .string(name),
                    "layout": .string("tiles"),
                    "orientation": .string("horizontal"),
                    "focused": .bool(true),
                    "visible": .bool(true),
                    "nodes": .array([]),
                    "floating-windows": .array([]),
                ]),
            ]),
        ]))
        let result = await parseCommand("get_tree").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.stdout, [expected])
    }
}

private func rootJson(_ monitors: [Json]) -> Json {
    .dict([
        "type": .string("root"),
        "monitors": .array(monitors),
    ])
}

private func monitorJson(_ workspaces: [Json]) -> Json {
    .dict([
        "type": .string("monitor"),
        "id": .int(1),
        "name": .string("Test Monitor"),
        "workspaces": .array(workspaces),
    ])
}

private func windowJson(_ id: UInt32, focused: Bool = false) -> Json {
    .dict([
        "type": .string("window"),
        "window-id": .int(id),
        "window-title": .string("TestWindow(\(id))"),
        "app-bundle-id": .string("bobko.AeroSpace.test-app"),
        "app-pid": .int(0),
        "focused": .bool(focused),
        "fullscreen": .bool(false),
    ])
}
