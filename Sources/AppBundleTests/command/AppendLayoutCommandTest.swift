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

        // Step 1: Capture tree as JSON
        let getTreeResult = try await GetTreeCommand(args: GetTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(getTreeResult.exitCode, 0)
        let fullJson = getTreeResult.stdout.joined()

        // Extract the "tiling" portion (append-layout expects a container, not workspace)
        let parsed = try JSONSerialization.jsonObject(with: fullJson.data(using: .utf8)!) as! [String: Any]
        let tilingJson = parsed["tiling"]!
        let tilingData = try JSONSerialization.data(withJSONObject: tilingJson, options: [.prettyPrinted, .sortedKeys])
        let tilingString = String(data: tilingData, encoding: .utf8)!

        // Step 2: Flatten the workspace
        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()
        // Verify it's now flat
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2), .window(3)])]))

        // Step 3: Apply captured JSON via append-layout
        let appendResult = try await AppendLayoutCommand(args: AppendLayoutCmdArgs(rawArgs: [])).run(.defaultEnv, CmdStdin(tilingString))
        assertEquals(appendResult.exitCode, 0)

        // Step 4: Verify tree matches original
        assertEquals(workspace.layoutDescription, originalLayout)
    }
}
