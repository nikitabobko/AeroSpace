import XCTest
@testable import AeroSpace_Debug

/*
todo write tests

test 1
    horizontal
        window1
        vertical
            vertical
                window2 <-- focused
            vertical
                window5
                horizontal
                    window3
                    window4
pre-condition: focus_wrapping force_workspace
action: focus up
expected: mru(window3, window4) is focused

*/

final class FocusCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }
    override func tearDownWithError() throws { tearDownWorkspacesForTests() }

    func testFocus() async {
        XCTAssertEqual(focusedWindow, nil)
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0).focus()
            TestWindow(id: 3, parent: $0)
        }
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusAlongTheContainerOrientation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await FocusCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusAcrossTheContainerOrientation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await FocusCommand(direction: .up).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 1)
        await FocusCommand(direction: .down).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusNoWrapping() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await FocusCommand(direction: .left).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusFindMruLeaf() async {
        let workspace = Workspace.get(byName: name)
        var startWindow: Window!
        var window2: Window!
        var window3: Window!
        var unrelatedWindow: Window!
        workspace.rootTilingContainer.apply {
            startWindow = TestWindow(id: 1, parent: $0).apply { $0.focus() }
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                    window2 = TestWindow(id: 2, parent: $0)
                    unrelatedWindow = TestWindow(id: 5, parent: $0)
                }
                window3 = TestWindow(id: 3, parent: $0)
            }
        }

        XCTAssertEqual(workspace.mostRecentWindow?.windowId, 3) // The latest binded
        await FocusCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 3)

        startWindow.focus()
        window2.markAsMostRecentChild()
        await FocusCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 2)

        startWindow.focus()
        window3.markAsMostRecentChild()
        unrelatedWindow.markAsMostRecentChild()
        await FocusCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusOutsideOfTheContainer() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 2, parent: $0).focus()
            }
        }

        await FocusCommand(direction: .left).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusOutsideOfTheContainer2() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 2, parent: $0).focus()
            }
        }

        await FocusCommand(direction: .left).runWithoutRefresh()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }
}
