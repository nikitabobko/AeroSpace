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

    func testFocus() {
        XCTAssertEqual(focusedWindow, nil)
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            start = TestWindow(id: 2, parent: $0)
            TestWindow(id: 3, parent: $0)
        }
        start.focus()
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusAlongTheContainerOrientation() {
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        FocusCommand(direction: .right).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusAcrossTheContainerOrientation() {
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        FocusCommand(direction: .up).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 1)
        FocusCommand(direction: .down).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusNoWrapping() {
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        FocusCommand(direction: .left).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusFindMruLeaf() {
        let workspace = Workspace.get(byName: name)
        var startWindow: Window!
        var window2: Window!
        var window3: Window!
        var unrelatedWindow: Window!
        workspace.rootTilingContainer.apply {
            startWindow = TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    window2 = TestWindow(id: 2, parent: $0)
                    unrelatedWindow = TestWindow(id: 5, parent: $0)
                }
                window3 = TestWindow(id: 3, parent: $0)
            }
        }

        XCTAssertEqual(workspace.mostRecentWindow?.windowId, 3) // The latest bound
        startWindow.focus()
        FocusCommand(direction: .right).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 3)

        window2.markAsMostRecentChild()
        startWindow.focus()
        FocusCommand(direction: .right).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 2)

        window3.markAsMostRecentChild()
        unrelatedWindow.markAsMostRecentChild()
        startWindow.focus()
        FocusCommand(direction: .right).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testFocusOutsideOfTheContainer() {
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                start = TestWindow(id: 2, parent: $0)
            }
        }
        start.focus()

        FocusCommand(direction: .left).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }

    func testFocusOutsideOfTheContainer2() {
        var start: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                start = TestWindow(id: 2, parent: $0)
            }
        }
        start.focus()

        FocusCommand(direction: .left).testRun()
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }
}

extension Command {
    func testRun() { // todo drop
        check(Thread.current.isMainThread)
        var state: CommandSubject
        if let window = focusedWindow {
            state = .window(window)
        } else {
            state = .emptyWorkspace(focusedWorkspaceName)
        }
        run(&state)
    }
}
