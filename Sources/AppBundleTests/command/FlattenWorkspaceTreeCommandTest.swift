@testable import AppBundle
import Common
import XCTest

@MainActor
final class FlattenWorkspaceTreeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                }
            }
            TestWindow.new(id: 3, parent: $0) // floating
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        // normalizeContainers() is now called inside the command, so no need to call it here.
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2)]), .window(3)]))
    }

    func testDeeplyNested() async throws {
        // Verify flatten fully normalizes a deeply nested tree (no residual containers).
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                        TestWindow.new(id: 3, parent: $0)
                        TestWindow.new(id: 4, parent: $0)
                    }
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        // Before flatten: root → [window(1), v_tiles → [window(2), h_tiles → [window(3), window(4)]]]
        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        // After flatten: all windows are direct children of root, no residual containers.
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2), .window(3), .window(4)])]))
    }
}
