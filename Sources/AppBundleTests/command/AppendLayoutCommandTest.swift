@testable import AppBundle
import Common
import XCTest

@MainActor
final class AppendLayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testAppendLayoutSimple() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "vertical",
                "children": [
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"},
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"}
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)
        assertEquals(workspace.layoutDescription, .workspace([.v_tiles([.window(1), .window(2)])]))
    }

    func testAppendLayoutNested() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 4, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Nested layout: h_tiles with [v_tiles[win, win], v_tiles[win, win]]
        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "horizontal",
                "children": [
                    {
                        "type": "container",
                        "layout": "tiles",
                        "orientation": "vertical",
                        "children": [
                            {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"},
                            {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"}
                        ]
                    },
                    {
                        "type": "container",
                        "layout": "tiles",
                        "orientation": "vertical",
                        "children": [
                            {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"},
                            {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"}
                        ]
                    }
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)
        assertEquals(workspace.layoutDescription, .workspace([
            .h_tiles([
                .v_tiles([.window(1), .window(2)]),
                .v_tiles([.window(3), .window(4)]),
            ]),
        ]))
    }

    func testAppendLayoutUnmatchedWindowsRemainFlat() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Spec only has 2 window slots, workspace has 3 windows
        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "vertical",
                "children": [
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"},
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app"}
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)
        // Window 3 should remain as sibling in root since spec only needed 2
        assertEquals(workspace.layoutDescription, .workspace([.v_tiles([.window(1), .window(2), .window(3)])]))
    }

    func testAppendLayoutWindowIdMatching() async throws {
        // Create windows — all have the same bundle ID, but different window IDs
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Spec with explicit window-id: request window 2 first, window 1 second
        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "vertical",
                "children": [
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 2},
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 1}
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)
        // Window 2 should be first, window 1 second (reversed from creation order)
        assertEquals(workspace.layoutDescription, .workspace([.v_tiles([.window(2), .window(1)])]))
    }

    func testAppendLayoutPreservesWeights() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Spec with custom weights (70/30 split)
        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "horizontal",
                "children": [
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 1, "weight": 7.0},
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 2, "weight": 3.0}
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)

        let root = workspace.rootTilingContainer
        let children = root.children
        assertEquals(children.count, 2)
        assertEquals(children[0].getWeight(.h), 7.0)
        assertEquals(children[1].getWeight(.h), 3.0)
    }

    func testAppendLayoutMissingWindowPreservesStructure() async throws {
        // Workspace has 2 windows, but spec has a 3-slot nested layout
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Spec: h_tiles[ win1, v_tiles[ win2, missing_win ] ]
        // The missing_win slot has a non-existent bundle ID
        let json = """
            {
                "type": "container",
                "layout": "tiles",
                "orientation": "horizontal",
                "children": [
                    {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 1},
                    {
                        "type": "container",
                        "layout": "tiles",
                        "orientation": "vertical",
                        "children": [
                            {"type": "window", "app-bundle-id": "bobko.AeroSpace.test-app", "window-id": 2},
                            {"type": "window", "app-bundle-id": "com.nonexistent.app"}
                        ]
                    }
                ]
            }
            """

        let result = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(json))
        assertEquals(result.exitCode, 0)
        // Container structure should be preserved even with missing window
        // v_tiles has only 1 child (win2) but the container itself survives
        assertEquals(workspace.layoutDescription, .workspace([
            .h_tiles([
                .window(1),
                .v_tiles([.window(2)]),
            ]),
        ]))
    }

    func testRoundTrip() async throws {
        // Build a non-trivial tree manually
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        let originalLayout = workspace.layoutDescription

        // Step 1: Capture tree as JSON (includes weights and window-ids)
        let getTreeResult = try await GetTreeCommand(args: GetTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(getTreeResult.exitCode, 0)
        let fullJson = getTreeResult.stdout.joined()

        // Step 2: Flatten the workspace
        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2), .window(3)])]))

        // Step 3: Apply full get-tree output directly (with workspace wrapper)
        let appendResult = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(fullJson))
        assertEquals(appendResult.exitCode, 0)

        // Step 4: Verify tree matches original
        assertEquals(workspace.layoutDescription, originalLayout)
    }
}
