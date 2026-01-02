@testable import AppBundle
import Common
import XCTest

// todo write tests
//
// test 1
//     horizontal
//         window1
//         vertical
//             vertical
//                 window2 <-- focused
//             vertical
//                 window5
//                 horizontal
//                     window3
//                     window4
// pre-condition: focus_wrapping force_workspace
// action: focus up
// expected: mru(window3, window4) is focused

@MainActor
final class FocusCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        XCTAssertTrue(parseCommand("focus --boundaries left").errorOrNil?.contains("Possible values") == true)
        var expected = FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .direction(.left))
        expected.rawBoundaries = .workspace
        testParseCommandSucc("focus --boundaries workspace left", expected)

        assertEquals(
            parseCommand("focus --boundaries workspace --boundaries workspace left").errorOrNil,
            "ERROR: Duplicated option '--boundaries'",
        )
        assertEquals(
            parseCommand("focus --window-id 42 --ignore-floating").errorOrNil,
            "--window-id is incompatible with other options",
        )
        assertEquals(
            parseCommand("focus --boundaries all-monitors-outer-frame dfs-next").errorOrNil,
            "(dfs-next|dfs-prev) only supports --boundaries workspace",
        )
    }

    func testFocus() {
        assertEquals(focus.windowOrNil, nil)
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusOverFloatingWindows() async throws {
        assertEquals(focus.windowOrNil, nil)
        Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
            assertEquals(TestWindow.new(id: 2, parent: $0, rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100)).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0, rect: Rect(topLeftX: 20, topLeftY: 20, width: 100, height: 100))
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testFocusAlongTheContainerOrientation() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusAcrossTheContainerOrientation() async throws {
        Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
            assertEquals($0.focusWorkspace(), true)
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .up).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(direction: .down).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusNoWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        var args = FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .direction(.left))
        args.rawBoundaries = .workspace
        args.rawBoundariesAction = .wrapAroundTheWorkspace
        try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusFindMruLeaf() async throws {
        let workspace = Workspace.get(byName: name)
        var startWindow: Window!
        var window2: Window!
        var window3: Window!
        var unrelatedWindow: Window!
        workspace.rootTilingContainer.apply {
            startWindow = TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    window2 = TestWindow.new(id: 2, parent: $0)
                    unrelatedWindow = TestWindow.new(id: 5, parent: $0)
                }
                window3 = TestWindow.new(id: 3, parent: $0)
            }
        }

        assertEquals(workspace.mostRecentWindowRecursive?.windowId, 3) // The latest bound
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)

        window2.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)

        window3.markAsMostRecentChild()
        unrelatedWindow.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        try await FocusCommand.new(direction: .right).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusOutsideOfTheContainer() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusOutsideOfTheContainer2() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        try await FocusCommand.new(direction: .left).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelative() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
            TestWindow.new(id: 4, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)

        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        try await FocusCommand.new(dfsRelative: .dfsNext).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 4)

        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        try await FocusCommand.new(dfsRelative: .dfsPrev).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelativeWrapping() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)

        var args = FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .dfsRelative(.dfsPrev))

        args.rawBoundariesAction = .stop
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.rawBoundariesAction = .fail
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.rawBoundariesAction = .wrapAroundTheWorkspace
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.cardinalOrDfsDirection = .dfsRelative(.dfsNext)

        args.rawBoundariesAction = .stop
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.rawBoundariesAction = .fail
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 2)

        args.rawBoundariesAction = .wrapAroundTheWorkspace
        assertEquals(try await FocusCommand(args: args).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusHistoryBackForward() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        var w2: Window!
        var w3: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
            w2 = TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
        }

        // Build focus history: w1 -> w2 -> w3
        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w2.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w3.focusWindow(), true)
        checkOnFocusChangedCallbacks()

        assertEquals(focus.windowOrNil?.windowId, 3)

        // Go back to w2
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        // Go back to w1
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)

        // Go forward to w2
        assertEquals(try await FocusCommand.new(historyNavigation: .forward).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        // Go forward to w3
        assertEquals(try await FocusCommand.new(historyNavigation: .forward).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 3)

        // Forward at end should fail
        assertEquals(try await FocusCommand.new(historyNavigation: .forward).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testFocusHistoryTruncation() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        var w2: Window!
        var w3: Window!
        var w4: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
            w2 = TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
            w4 = TestWindow.new(id: 4, parent: $0)
        }

        // Build focus history: w1 -> w2 -> w3
        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w2.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w3.focusWindow(), true)
        checkOnFocusChangedCallbacks()

        // Go back to w2
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        // Focus new window w4 (should truncate forward history)
        assertEquals(w4.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(focus.windowOrNil?.windowId, 4)

        // Forward should now fail (w3 was truncated from history)
        assertEquals(try await FocusCommand.new(historyNavigation: .forward).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 4)

        // But back should work and go to w2
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusHistoryAtBeginning() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
        }

        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(focus.windowOrNil?.windowId, 1)

        // Back at beginning should fail
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 1)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusHistorySkipsClosedWindows() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        var w2: Window!
        var w3: Window!
        var w4: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
            w2 = TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
            w4 = TestWindow.new(id: 4, parent: $0)
        }

        // Build focus history: w1 -> w2 -> w3 -> w4
        // Start with w1 to establish initial focus, then cycle through
        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w2.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w3.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w4.focusWindow(), true)
        checkOnFocusChangedCallbacks()

        assertEquals(focus.windowOrNil?.windowId, 4)

        // Close w3 (a middle window in history)
        w3.closeAxWindow()

        // Go back should skip w3 and go directly to w2
        assertEquals(try await FocusCommand.new(historyNavigation: .back).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        // Go forward should skip w3 and go directly to w4
        assertEquals(try await FocusCommand.new(historyNavigation: .forward).run(.defaultEnv, .emptyStdin).exitCode, 0)
        assertEquals(focus.windowOrNil?.windowId, 4)
    }

    func testFocusHistoryParsing() {
        testParseCommandSucc("focus back", FocusCmdArgs(rawArgs: [], historyNavigation: .back))
        testParseCommandSucc("focus forward", FocusCmdArgs(rawArgs: [], historyNavigation: .forward))

        // back/forward should be incompatible with other flags
        XCTAssertTrue(parseCommand("focus --ignore-floating back").errorOrNil?.contains("incompatible") == true)
        XCTAssertTrue(parseCommand("focus --boundaries workspace back").errorOrNil?.contains("incompatible") == true)
    }

    func testFocusBackAndForth() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        var w2: Window!
        var w3: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
            w2 = TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
        }

        // Build focus history: w1 -> w2 -> w3
        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w2.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w3.focusWindow(), true)
        checkOnFocusChangedCallbacks()

        assertEquals(focus.windowOrNil?.windowId, 3)

        // Back-and-forth should go to w2
        assertEquals(try await FocusBackAndForthCommand(args: FocusBackAndForthCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)
        checkOnFocusChangedCallbacks()
        assertEquals(focus.windowOrNil?.windowId, 2)

        // Back-and-forth again should go back to w3
        assertEquals(try await FocusBackAndForthCommand(args: FocusBackAndForthCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)
        checkOnFocusChangedCallbacks()
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testFocusBackAndForthSkipsClosedWindows() async throws {
        let workspace = Workspace.get(byName: name)
        var w1: Window!
        var w2: Window!
        var w3: Window!
        workspace.rootTilingContainer.apply {
            w1 = TestWindow.new(id: 1, parent: $0)
            w2 = TestWindow.new(id: 2, parent: $0)
            w3 = TestWindow.new(id: 3, parent: $0)
        }

        // Build focus history: w1 -> w2 -> w3
        assertEquals(w1.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w2.focusWindow(), true)
        checkOnFocusChangedCallbacks()
        assertEquals(w3.focusWindow(), true)
        checkOnFocusChangedCallbacks()

        assertEquals(focus.windowOrNil?.windowId, 3)

        // Close w2 (the previous window)
        w2.closeAxWindow()

        // Back-and-forth should skip w2 and go to w1
        assertEquals(try await FocusBackAndForthCommand(args: FocusBackAndForthCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)
        checkOnFocusChangedCallbacks()
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}

extension FocusCommand {
    static func new(direction: CardinalDirection) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .direction(direction)))
    }
    static func new(dfsRelative: DfsNextPrev) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], cardinalOrDfsDirection: .dfsRelative(dfsRelative)))
    }
    static func new(historyNavigation: HistoryNavigation) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], historyNavigation: historyNavigation))
    }
}
