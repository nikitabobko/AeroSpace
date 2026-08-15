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
        testParseSingleCommandSucc("focus --boundaries workspace left", expected)

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

        assertEquals(
            parseCommand("focus --window-id 42 --wrap-around").errorOrNil,
            "--window-id is incompatible with other options",
        )
        assertEquals(
            parseCommand("focus left --boundaries-action wrap-around-the-workspace --wrap-around").errorOrNil,
            "ERROR: Conflicting options: --boundaries-action, --wrap-around",
        )
        assertEquals(
            parseCommand("focus dfs-next --fail-if-fullscreen").errorOrNil,
            "--fail-if-fullscreen/--fail-if-macos-native-fullscreen require using (left|down|up|right) argument",
        )
        assertEquals(
            parseCommand("focus --fail-if-macos-native-fullscreen --window-id 42").errorOrNil,
            "--window-id is incompatible with other options",
        )
        assertNil(parseCommand("focus --fail-if-fullscreen --fail-if-macos-native-fullscreen left").errorOrNil)
    }

    func testFailIfFullscreen() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            let window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
            window.isFullscreen = true
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("focus --fail-if-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFailIfMacosNativeFullscreen() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            let window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
            window.isMacosFullscreenForTest = true

            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("focus --fail-if-macos-native-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFailIfFullscreenAllowsRegularWindows() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("focus --fail-if-fullscreen --fail-if-macos-native-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)
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

    func testFocusOverFloatingWindows() async {
        assertEquals(focus.windowOrNil, nil)
        Workspace.get(byName: name).floatingWindowsContainer.apply {
            TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
            assertEquals(TestWindow.new(id: 2, parent: $0, rect: Rect(topLeftX: 10, topLeftY: 10, width: 100, height: 100)).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0, rect: Rect(topLeftX: 20, topLeftY: 20, width: 100, height: 100))
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    // https://github.com/nikitabobko/AeroSpace/issues/1311
    // 'a' is suspended in the first getCenter of makeFloatingWindowsSeenAsTiling, 'b' unbinds the same floating window
    // meanwhile. Before the fix, 'a' died with "is already unbound" once it was resumed
    func testConcurrentFocusOverFloatingWindows() async throws {
        let workspace = Workspace.get(byName: name)
        let monitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
        // The tiling window covers the whole monitor, so that the second getCenter of the loop is reachable too
        let tiling = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, rect: monitorRect)
        tiling.lastAppliedLayoutVirtualRect = monitorRect
        let floating1 = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200))
        let floating2 = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 900, topLeftY: 500, width: 200, height: 200))
        assertEquals(tiling.focusWindow(), true)
        assertEquals(workspace.floatingWindows.map(\.windowId), [2, 3])

        let aSuspended = AwaitableOneTimeBroadcastLatch()
        let aResume = AwaitableOneTimeBroadcastLatch()
        floating1.onNextGetAxRectForTest = {
            await aSuspended.signalToAll()
            try await aResume.await()
        }
        let a = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await aSuspended.await()
        assertTrue(floating1.isBound) // 'a' hasn't unbound it yet

        // floating1's hook is already consumed, so 'b' unbinds floating1 and suspends on floating2
        let bSuspended = AwaitableOneTimeBroadcastLatch()
        let bResume = AwaitableOneTimeBroadcastLatch()
        floating2.onNextGetAxRectForTest = {
            await bSuspended.signalToAll()
            try await bResume.await()
        }
        let b = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await bSuspended.await()
        assertFalse(floating1.isBound)
        assertTrue(floating2.isBound)

        await aResume.signalToAll()
        await a.value
        await bResume.signalToAll()
        await b.value

        // Every floating window is bound back, none is lost, duplicated, or left in the tiling tree
        assertTrue(floating1.parent === workspace.floatingWindowsContainer)
        assertTrue(floating2.parent === workspace.floatingWindowsContainer)
        assertEquals(workspace.floatingWindows.map(\.windowId).sorted(), [2, 3])
        assertEquals(workspace.rootTilingContainer.allLeafWindowsRecursive.map(\.windowId), [1])
        assertTrue(tiling.parent === workspace.rootTilingContainer)
    }

    // https://github.com/nikitabobko/AeroSpace/issues/1311
    // The same race, but 'a' is suspended in the second getCenter of the loop (the AX read of the tiling window it is
    // about to be inserted next to). That's why both suspension points must re-validate the window
    func testConcurrentFocusOverFloatingWindows2() async throws {
        let workspace = Workspace.get(byName: name)
        let monitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
        let tiling = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, rect: monitorRect)
        tiling.lastAppliedLayoutVirtualRect = monitorRect
        let floating1 = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200))
        let floating2 = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 900, topLeftY: 500, width: 200, height: 200))
        assertEquals(tiling.focusWindow(), true)

        let aSuspended = AwaitableOneTimeBroadcastLatch()
        let aResume = AwaitableOneTimeBroadcastLatch()
        tiling.onNextGetAxRectForTest = {
            await aSuspended.signalToAll()
            try await aResume.await()
        }
        let a = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await aSuspended.await()
        assertTrue(floating1.isBound)

        let bSuspended = AwaitableOneTimeBroadcastLatch()
        let bResume = AwaitableOneTimeBroadcastLatch()
        floating2.onNextGetAxRectForTest = {
            await bSuspended.signalToAll()
            try await bResume.await()
        }
        let b = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await bSuspended.await()
        assertFalse(floating1.isBound)

        await aResume.signalToAll()
        await a.value
        await bResume.signalToAll()
        await b.value

        assertTrue(floating1.parent === workspace.floatingWindowsContainer)
        assertTrue(floating2.parent === workspace.floatingWindowsContainer)
        assertEquals(workspace.floatingWindows.map(\.windowId).sorted(), [2, 3])
        assertEquals(workspace.rootTilingContainer.allLeafWindowsRecursive.map(\.windowId), [1])
    }

    // https://github.com/nikitabobko/AeroSpace/issues/1311
    // The workspace from the report, where all the windows are floating. findWindowRecursively finds no tiling window
    // under the floating window center, so the loop takes the branch that never reaches the second getCenter, and the
    // first check is the only thing that stands between 'a' and the already unbound window
    func testConcurrentFocusOverFloatingWindows3() async throws {
        let workspace = Workspace.get(byName: name)
        let floating1 = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 200))
        let floating2 = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 900, topLeftY: 500, width: 200, height: 200))
        assertEquals(floating1.focusWindow(), true)
        assertEquals(workspace.rootTilingContainer.allLeafWindowsRecursive.map(\.windowId), [])

        let aSuspended = AwaitableOneTimeBroadcastLatch()
        let aResume = AwaitableOneTimeBroadcastLatch()
        floating1.onNextGetAxRectForTest = {
            await aSuspended.signalToAll()
            try await aResume.await()
        }
        let a = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await aSuspended.await()
        assertTrue(floating1.isBound)

        let bSuspended = AwaitableOneTimeBroadcastLatch()
        let bResume = AwaitableOneTimeBroadcastLatch()
        floating2.onNextGetAxRectForTest = {
            await bSuspended.signalToAll()
            try await bResume.await()
        }
        let b = Task.startUnstructured { _ = await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin) }
        try await bSuspended.await()
        assertFalse(floating1.isBound)

        await aResume.signalToAll()
        await a.value
        await bResume.signalToAll()
        await b.value

        assertTrue(floating1.parent === workspace.floatingWindowsContainer)
        assertTrue(floating2.parent === workspace.floatingWindowsContainer)
        assertEquals(workspace.floatingWindows.map(\.windowId).sorted(), [1, 2])
        assertEquals(workspace.rootTilingContainer.allLeafWindowsRecursive.map(\.windowId), [])
    }

    func testFocusAlongTheContainerOrientation() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusAcrossTheContainerOrientation() async {
        Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
            assertEquals($0.focusWorkspace(), true)
        }

        assertEquals(focus.windowOrNil?.windowId, 2)
        await parseCommand("focus up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        await parseCommand("focus down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusNoWrapping() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusWrapping() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        await parseCommand("focus --boundaries workspace --boundaries-action wrap-around-the-workspace left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusFindMruLeaf() async {
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
        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)

        window2.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)

        window3.markAsMostRecentChild()
        unrelatedWindow.markAsMostRecentChild()
        _ = startWindow.focusWindow()
        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testFocusOutsideOfTheContainer() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusOutsideOfTheContainer2() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            }
        }

        await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelative() async {
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

        await parseCommand("focus dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        await parseCommand("focus dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        await parseCommand("focus dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 4)

        await parseCommand("focus dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 3)
        await parseCommand("focus dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 2)
        await parseCommand("focus dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testFocusDfsRelativeWrapping() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)

        assertEquals(await parseCommand("focus --boundaries-action stop dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)

        assertEquals(await parseCommand("focus --boundaries-action fail dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 2)
        assertEquals(focus.windowOrNil?.windowId, 1)

        assertEquals(await parseCommand("focus --boundaries-action wrap-around-the-workspace dfs-prev").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        assertEquals(await parseCommand("focus --boundaries-action stop dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, 2)

        assertEquals(await parseCommand("focus --boundaries-action fail dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 2)
        assertEquals(focus.windowOrNil?.windowId, 2)

        assertEquals(await parseCommand("focus --boundaries-action wrap-around-the-workspace dfs-next").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}
