import XCTest
@testable import AeroSpace_Debug

final class FlattenWorkspaceTreeCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testSimple() {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow(id: 1, parent: $0).focus()
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
            TestWindow(id: 3, parent: $0) // floating
        }

        FlattenWorkspaceTreeCommand().testRun()
        workspace.normalizeContainers()
        XCTAssertEqual(workspace.layoutDescription, .workspace([.h_tiles([.window(1), .window(2)]), .window(3)]))
    }
}
