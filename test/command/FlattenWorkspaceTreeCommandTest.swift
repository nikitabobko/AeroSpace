import XCTest
@testable import AeroSpace_Debug

final class FlattenWorkspaceTreeCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }
    override func tearDownWithError() throws { tearDownWorkspacesForTests() }

    func testSimple() async {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow(id: 1, parent: $0).focus()
                TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
            TestWindow(id: 3, parent: $0) // floating
        }

        await FlattenWorkspaceTreeCommand().runWithoutRefresh()
        workspace.rootTilingContainer.normalizeContainersRecursive()
        XCTAssertEqual(workspace.layoutDescription, .workspace([.h_list([.window(1), .window(2)]), .window(3)]))
    }
}
