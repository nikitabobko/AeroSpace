@testable import AppBundle
import Common
import XCTest

@MainActor
final class GetTreeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testGetTreeSimple() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        let result = try await GetTreeCommand(args: GetTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)

        let json = try parseJson(result.stdout.joined())
        assertEquals(json["type"] as? String, "workspace")

        let tiling = json["tiling"] as! [String: Any]
        assertEquals(tiling["type"] as? String, "container")
        assertEquals(tiling["layout"] as? String, "tiles")
        assertEquals(tiling["orientation"] as? String, "horizontal")

        let children = tiling["children"] as! [[String: Any]]
        assertEquals(children.count, 2)
        assertEquals(children[0]["type"] as? String, "window")
        assertEquals(children[0]["window-id"] as? UInt32, 1)
        assertEquals(children[0]["app-bundle-id"] as? String, "bobko.AeroSpace.test-app")
        assertEquals(children[1]["type"] as? String, "window")
        assertEquals(children[1]["window-id"] as? UInt32, 2)

        let floating = json["floating"] as! [Any]
        assertEquals(floating.count, 0)
    }

    func testGetTreeNested() async throws {
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

        let result = try await GetTreeCommand(args: GetTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)

        let json = try parseJson(result.stdout.joined())
        let tiling = json["tiling"] as! [String: Any]
        assertEquals(tiling["orientation"] as? String, "horizontal")

        let children = tiling["children"] as! [[String: Any]]
        assertEquals(children.count, 2)
        assertEquals(children[0]["type"] as? String, "window")
        assertEquals(children[0]["window-id"] as? UInt32, 1)

        let nested = children[1]
        assertEquals(nested["type"] as? String, "container")
        assertEquals(nested["layout"] as? String, "tiles")
        assertEquals(nested["orientation"] as? String, "vertical")
        let nestedChildren = nested["children"] as! [[String: Any]]
        assertEquals(nestedChildren.count, 2)
        assertEquals(nestedChildren[0]["window-id"] as? UInt32, 2)
        assertEquals(nestedChildren[1]["window-id"] as? UInt32, 3)
    }

    func testGetTreeIncludesFloating() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
            TestWindow.new(id: 2, parent: $0) // floating
        }
        assertEquals(workspace.focusWorkspace(), true)

        let result = try await GetTreeCommand(args: GetTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)

        let json = try parseJson(result.stdout.joined())
        let floating = json["floating"] as! [[String: Any]]
        assertEquals(floating.count, 1)
        assertEquals(floating[0]["type"] as? String, "window")
        assertEquals(floating[0]["window-id"] as? UInt32, 2)
    }
}

private func parseJson(_ string: String) throws -> [String: Any] {
    let data = string.data(using: .utf8)!
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}
