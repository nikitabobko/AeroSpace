@testable import AppBundle
import Common
import XCTest

final class FlattenWorkspaceTreeCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSimple() {
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

        FlattenWorkspaceTreeCommand().run(.focused)
        workspace.normalizeContainers()
        assertEquals(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2)]), .window(3)]))
    }
}
