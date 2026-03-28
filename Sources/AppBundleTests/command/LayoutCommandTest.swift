@testable import AppBundle
import Common
import XCTest

@MainActor
final class LayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testChangeLayout() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }
        // Root defaults to h_tiles. Change to v_tiles.
        let result = try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.v_tiles])).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(root.layoutDescription, .v_tiles([.window(1), .window(2)]))
    }

    func testNoopReturnsTrueWhenLayoutAlreadyMatches() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
        }
        // Root defaults to h_tiles. Setting h_tiles again should succeed (noop).
        let result = try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.h_tiles])).run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }
}
