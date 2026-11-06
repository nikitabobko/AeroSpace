@testable import AppBundle
import Common
import Foundation
import Testing

@MainActor
@Suite(.serializedGlobally)
struct DumpWorkspaceTreeTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertEquals(parseCommand("dump-workspace-tree").errorOrNil, "Mandatory option is not specified (--all|--monitor|--workspace)")
        assertEquals(parseCommand("dump-workspace-tree --all --workspace M").errorOrNil, "ERROR: Conflicting flags: --all, --workspace")
        assertEquals(parseCommand("dump-workspace-tree --all --monitor mouse").errorOrNil, "ERROR: Conflicting flags: --all, --monitor")
        assertNil(parseCommand("dump-workspace-tree --all").errorOrNil)
        assertNil(parseCommand("dump-workspace-tree --workspace focused visible M").errorOrNil)
        assertNil(parseCommand("dump-workspace-tree --monitor 1 --workspace M").errorOrNil)
    }

    @Test func testRunEmptyWorkspace() async throws {
        let result = await parseCommand("dump-workspace-tree --workspace empty").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        let dump = try parse(result.stdout)
        assertEquals(dump.count, 1)
        assertEquals(dump[0]["workspace"] as? String, "empty")
        assertEquals(dump[0]["workspace-is-focused"] as? Bool, false)
        let root = try #require(dump[0]["root"] as? [String: Any])
        assertEquals(root["type"] as? String, "container")
        assertEquals(root["path"] as? String, "/")
        assertEquals(root["layout"] as? String, "h_tiles")
        assertEquals((root["children"] as? [Any])?.count, 0)
        assertEquals((dump[0]["floating-windows"] as? [Any])?.count, 0)
    }

    @Test func testRunTree() async throws {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        TestWindow.new(id: 4, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 10, topLeftY: 20, width: 30, height: 40))
        assertEquals(workspace.focusWorkspace(), true)

        let all = await parseCommand("dump-workspace-tree --all").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(all.exitCode.rawValue, 0)
        assertEquals(try parse(all.stdout).map { $0["workspace"] as? String }, ["a", "setUpWorkspacesForTests"])

        let result = await parseCommand("dump-workspace-tree --workspace a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        let dump = try parse(result.stdout)
        assertEquals(dump.map { $0["workspace"] as? String }, ["a"])
        assertEquals(dump[0]["workspace-is-focused"] as? Bool, true)
        assertEquals(dump[0]["workspace-is-visible"] as? Bool, true)

        let root = try #require(dump[0]["root"] as? [String: Any])
        assertEquals(root["layout"] as? String, "h_tiles")
        let children = try #require(root["children"] as? [[String: Any]])
        assertEquals(children.map { $0["type"] as? String }, ["window", "container"])
        assertEquals(children.map { $0["path"] as? String }, ["/0", "/1"])
        assertEquals(children[0]["window-id"] as? Int, 1)
        assertEquals(children[0]["window-title"] as? String, "TestWindow(1)")
        assertEquals(children[0]["app-bundle-id"] as? String, "bobko.AeroSpace.test-app")
        assertEquals(children[1]["layout"] as? String, "v_tiles")
        let nested = try #require(children[1]["children"] as? [[String: Any]])
        assertEquals(nested.map { $0["window-id"] as? Int }, [2, 3])
        assertEquals(nested.map { $0["path"] as? String }, ["/1/0", "/1/1"])

        // Frames: h_tiles splits the width in half, v_tiles splits the height of the right half
        let workspaceRect = try #require(dump[0]["workspace-rect"] as? [String: Int])
        let w1 = try #require(children[0]["rect"] as? [String: Int])
        let w2 = try #require(nested[0]["rect"] as? [String: Int])
        let w3 = try #require(nested[1]["rect"] as? [String: Int])
        assertEquals(w1["x"], workspaceRect["x"])
        assertEquals(w1["width"], workspaceRect["width"]! / 2)
        assertEquals(w2["x"], workspaceRect["x"]! + workspaceRect["width"]! / 2)
        assertEquals(w2["width"], workspaceRect["width"]! / 2)
        assertEquals(w3["y"], w2["y"]! + w2["height"]!)
        assertTrue(abs(w2["height"]! + w3["height"]! - w1["height"]!) <= 1) // Frames are rounded to integer points

        let floating = try #require(dump[0]["floating-windows"] as? [[String: Any]])
        assertEquals(floating.map { $0["window-id"] as? Int }, [4])
        assertNil(floating[0]["path"])
        assertEquals(floating[0]["rect"] as? [String: Int], ["x": 10, "y": 20, "width": 30, "height": 40])
    }

    @Test func testRunInvisibleWorkspaceIsMeasured() async throws {
        let invisible = Workspace.get(byName: "b")
        invisible.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        TestWindow.new(id: 3, parent: Workspace.get(byName: "a").rootTilingContainer)
        assertEquals(Workspace.get(byName: "a").focusWorkspace(), true)
        assertEquals(invisible.isVisible, false)

        let result = await parseCommand("dump-workspace-tree --workspace b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        let dump = try parse(result.stdout)
        assertEquals(dump[0]["workspace-is-visible"] as? Bool, false)
        let root = try #require(dump[0]["root"] as? [String: Any])
        let children = try #require(root["children"] as? [[String: Any]])
        let w1 = try #require(children[0]["rect"] as? [String: Int])
        let w2 = try #require(children[1]["rect"] as? [String: Int])
        assertEquals(w1["width"], w2["width"])
        assertEquals(w2["x"], w1["x"]! + w1["width"]!)
        // Measuring must not mutate the tree
        assertEquals(invisible.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    @Test func testRunFilterByMonitor() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("dump-workspace-tree --monitor 99").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Invalid monitor ID: 99"])
    }

    private func parse(_ stdout: [String]) throws -> [[String: Any]] {
        let data = try #require(stdout.joined(separator: "\n").data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
