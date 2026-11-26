@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct NativeTabsTest {
    init() { setUpWorkspacesForTests() }

    @Test func testNewTabAndTabSwitchesKeepTheNode() throws {
        let app = FakeApp(windows: [1])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.newTab(2, in: "A", of: 1)
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])

        for frontmostTab: UInt32 in [1, 2, 1] {
            app.select(frontmostTab, in: "A")
            try model.refresh(app)
            #expect(model.node(frontmostTab) == node)
            #expect(model.tree == [node: .alive])
        }
        #expect(app.windowServerCalls == 1)
    }

    @Test func testTwoTabGroupsSwitchTabsInOneRefresh() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2], "B": [3, 4]])
        var model = Model()
        try model.refresh(app)
        let (a, b) = (try #require(model.node(1)), try #require(model.node(3)))

        app.select(2, in: "A")
        app.select(4, in: "B")
        try model.refresh(app)
        #expect(model.node(2) == a)
        #expect(model.node(4) == b)
        #expect(model.tree == [a: .alive, b: .alive])
    }

    @Test func testMergeAllWindows() throws {
        let app = FakeApp(windows: [1, 2, 3])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.tabGroups["A"] = [1, 2, 3]
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        app.select(3, in: "A")
        try model.refresh(app)
        #expect(model.tree == [node: .alive])
        #expect(model.node(3) == node)
    }

    @Test func testCloseFrontmostTab() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.close(1)
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])

        app.close(2)
        try model.refresh(app)
        #expect(model.node(3) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testCloseBackgroundTabs() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        for tab: UInt32 in [3, 2] {
            app.close(tab)
            try model.refresh(app)
            #expect(model.node(1) == node)
            #expect(model.tree == [node: .alive])
        }
    }

    @Test func testSeparateWindowsDontMerge() throws {
        let app = FakeApp(windows: [1, 2])
        var model = Model()
        try model.refresh(app)
        let (node1, node2) = (try #require(model.node(1)), try #require(model.node(2)))

        app.close(1)
        app.windows.insert(3)
        try model.refresh(app)
        let node3 = try #require(model.node(3))
        #expect(model.tree == [node2: .alive, node3: .alive])
        #expect(node3 != node1)

        app.newTab(4, in: "A", of: 2)
        app.windows.insert(5)
        try model.refresh(app)
        #expect(model.node(4) == node2)
        #expect(model.node(5) != nil)
        #expect(model.tree.count == 3)
    }

    @Test func testTearOut() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.tearOut(1, from: "A")
        try model.refresh(app)
        #expect(model.node(2) == node)
        let tornOut = try #require(model.node(1))
        #expect(model.tree == [node: .alive, tornOut: .alive])

        app.tearOut(3, from: "A")
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.node(1) == tornOut)
        #expect(model.tree.count == 3)
    }

    @Test func testFrontmostTabClosesOrTabGroupClosesAndWindowOpens() throws {
        for closesTabGroup in [false, true] {
            let app = FakeApp(windows: [5], tabGroups: ["A": [1, closesTabGroup ? 2 : 3]])
            var model = Model()
            try model.refresh(app)
            let (tabGroup, window) = (try #require(model.node(1)), try #require(model.node(5)))

            app.close(1)
            if closesTabGroup {
                app.close(2)
                app.windows.insert(3)
            }
            try model.refresh(app)
            #expect(model.node(3) == tabGroup)
            #expect(model.node(5) == window)
            #expect(model.tree == [tabGroup: .alive, window: .alive])
        }
    }

    @Test func testFrontmostTabClosesAndWindowOpensInOneRefresh() throws {
        let app = FakeApp(windows: [5], tabGroups: ["A": [117, 114]])
        var model = Model()
        try model.refresh(app)
        let (tabGroup, window) = (try #require(model.node(117)), try #require(model.node(5)))

        app.close(117)
        app.windows.insert(120)
        try model.refresh(app)
        let (lastTab, newWindow) = (try #require(model.node(114)), try #require(model.node(120)))
        #expect(model.tree == [window: .alive, lastTab: .alive, newWindow: .alive])
        #expect(![lastTab, newWindow].contains(tabGroup))
    }

    @Test func testFrontmostOrBackgroundTabTornOutOfTwoTabGroup() throws {
        for tornOutTab: UInt32 in [1, 2] {
            let app = FakeApp(tabGroups: ["A": [1, 2]])
            var model = Model()
            try model.refresh(app)
            let tabGroup = try #require(model.node(1))

            app.tearOut(tornOutTab, from: "A")
            try model.refresh(app)
            #expect(model.node(1) == tabGroup)
            let otherTab = try #require(model.node(2))
            #expect(model.tree == [tabGroup: .alive, otherTab: .alive])
        }
    }

    @Test func testDragTabIntoAnotherTabGroup() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3], "B": [4, 5]])
        var model = Model()
        try model.refresh(app)
        let (a, b) = (try #require(model.node(1)), try #require(model.node(4)))

        app.hidden = [1]
        try model.refresh(app)
        #expect(model.tree == [a: .invisible, b: .alive])

        app.tabGroups["A"] = [2, 3]
        try model.refresh(app)
        #expect(model.node(2) == a)

        app.hidden = []
        app.tabGroups["B"] = [1, 4, 5]
        try model.refresh(app)
        #expect(model.node(2) == a)
        #expect(model.node(1) == b)
        #expect(model.tree == [a: .alive, b: .alive])
    }

    @Test func testDragTabIntoAnotherTabGroupInOneRefresh() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3], "B": [4, 5]])
        var model = Model()
        try model.refresh(app)
        let (a, b) = (try #require(model.node(1)), try #require(model.node(4)))

        app.tabGroups = ["A": [2, 3], "B": [1, 4, 5]]
        try model.refresh(app)
        #expect(model.node(2) == a)
        #expect(model.node(1) == b)
        #expect(model.tree == [a: .alive, b: .alive])

        app.tabGroups = ["A": [2, 3, 1], "B": [4, 5]]
        try model.refresh(app)
        #expect(model.node(2) == a)
        #expect(model.node(4) == b)
        #expect(model.tree == [a: .alive, b: .alive])
    }

    @Test func testFinderDetachesTabBarDuringTabSwitch() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.detachedTabBars = ["A"]
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        app.detachedTabBars = []
        app.select(2, in: "A")
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testNativeFullscreenTabGroupNextToWindow() throws {
        let app = FakeApp(windows: [1], tabGroups: ["A": [2, 3]])
        var model = Model()
        try model.refresh(app)
        let (window, tabGroup) = (try #require(model.node(1)), try #require(model.node(2)))

        app.hidden = [1]
        try model.refresh(app)
        app.select(3, in: "A")
        try model.refresh(app)
        #expect(model.node(3) == tabGroup)
        #expect(model.tree == [window: .invisible, tabGroup: .alive])

        app.hidden = [3]
        try model.refresh(app)
        #expect(model.node(1) == window)
        #expect(model.node(3) == tabGroup)
        #expect(model.tree == [window: .alive, tabGroup: .invisible])

        app.hidden = []
        try model.refresh(app)
        #expect(model.tree == [window: .alive, tabGroup: .alive])
    }

    @Test func testNativeFullscreenTransitionOfTabGroup() throws {
        let app = FakeApp(windows: [1], tabGroups: ["A": [2, 3]])
        var model = Model()
        try model.refresh(app)
        let (window, tabGroup) = (try #require(model.node(1)), try #require(model.node(2)))

        for (transitionWindow, isFullscreen): (UInt32, Bool) in [(4, true), (5, false)] {
            app.windows.insert(transitionWindow)
            app.hidden = [1, 2]
            app.unreadableTabBars = ["A"]
            try model.refresh(app)
            #expect(model.node(2) == tabGroup)

            app.windows.remove(transitionWindow)
            app.hidden = isFullscreen ? [1] : []
            app.unreadableTabBars = []
            try model.refresh(app)
            #expect(model.node(1) == window)
            #expect(model.node(2) == tabGroup)
        }
        #expect(model.tree == [window: .alive, tabGroup: .alive])
    }

    @Test func testUnseenTabGroupOnAnotherSpaceIsNotTheOtherWindow() throws {
        let app = FakeApp(windows: [1], tabGroups: ["A": [2, 3]])
        app.hidden = [2]
        var model = Model()
        try model.refresh(app)
        let window = try #require(model.node(1))

        app.hidden = [1]
        try model.refresh(app)
        let tabGroup = try #require(model.node(2))
        #expect(tabGroup != window)
        #expect(model.tree == [window: .invisible, tabGroup: .alive])
    }

    @Test func testFrontmostTabOfTabGroupOnAnotherSpaceCloses() throws {
        for tabGroup: [UInt32] in [[1, 2, 3], [1, 2]] {
            let app = FakeApp(windows: [5], tabGroups: ["A": tabGroup])
            var model = Model()
            try model.refresh(app)
            let (node, other) = (try #require(model.node(1)), try #require(model.node(5)))

            app.hidden = [1, 5]
            try model.refresh(app)
            #expect(model.tree == [node: .invisible, other: .invisible])

            app.close(1)
            for _ in 1 ... 2 {
                try model.refresh(app)
                #expect(model.node(2) == node)
                #expect(model.tree == [node: .alive, other: .invisible])
            }

            app.hidden = [2]
            try model.refresh(app)
            #expect(model.node(2) == node)
            #expect(model.tree == [node: .invisible, other: .alive])
        }
    }

    @Test func testNewTabWhenWindowServerDoesNotAnswer() throws {
        let app = FakeApp(windows: [1])
        app.windowServerFails = true
        var model = Model()
        try model.refresh(app)
        let window = try #require(model.node(1))

        app.newTab(2, in: "A", of: 1)
        try model.refresh(app)
        let newTab = try #require(model.node(2))
        #expect(newTab != window)
        #expect(model.tree == [window: .invisible, newTab: .alive])

        app.select(1, in: "A")
        try model.refresh(app)
        #expect(model.node(1) == newTab)
        #expect(model.tree == [newTab: .alive])
    }

    @Test func testLockScreen() throws {
        for axGoesBlankFirst in [true, false] {
            let app = FakeApp(windows: [1, 4], tabGroups: ["A": [2, 3]])
            var model = Model()
            try model.refresh(app)
            let nodes = try [1, 2, 4].map { try #require(model.node($0)) }

            if axGoesBlankFirst {
                app.isAxBlank = true
                try model.refresh(app)
            }
            app.isAxBlank = true
            try model.refresh(app, isScreenLocked: true)
            try model.refresh(app, isScreenLocked: true)

            app.isAxBlank = false
            try model.refresh(app)
            #expect(try [1, 2, 4].map { try #require(model.node($0)) } == nodes)
            #expect(model.tree == nodes.associate { _ in WindowLifeStatus.alive })

            app.select(3, in: "A")
            try model.refresh(app)
            #expect(model.node(3) == nodes[1])
            #expect(model.tree == nodes.associate { _ in WindowLifeStatus.alive })
        }
    }

    @Test func testCancelledRefreshLeavesNoTrace() throws {
        let app = FakeApp(windows: [4], tabGroups: ["A": [1, 2, 3], "B": [5, 6]])
        var model = Model()
        try model.refresh(app)
        func change() {
            app.close(4)
            app.select(2, in: "A")
            app.tearOut(5, from: "B")
        }
        change()
        var uninterrupted = model
        app.axCalls = 0
        try uninterrupted.refresh(app)
        let axCalls = app.axCalls

        for cancelAfter in 0 ..< axCalls {
            app.axCalls = 0
            app.cancelAfter = cancelAfter
            var cancelled = model
            #expect(throws: CancellationError.self) { try cancelled.refresh(app) }
            #expect(cancelled == model)
        }
        app.cancelAfter = nil
        try model.refresh(app)
        #expect(model == uninterrupted)
    }

    @Test func testAppFailsToListItsWindows() throws {
        let app = FakeApp(windows: [1, 4])
        var model = Model()
        try model.refresh(app)
        let (window, otherWindow) = (try #require(model.node(1)), try #require(model.node(4)))
        app.hidden = [4]
        try model.refresh(app)

        app.newTab(2, in: "A", of: 1)
        app.failsToListWindows = true
        try model.refresh(app)
        #expect(model.tree == [window: .alive, otherWindow: .invisible])
        #expect(try model.focus(2, app) == nil)
        #expect(model.node(2) == nil)
        #expect(model.tree == [window: .alive, otherWindow: .invisible])

        app.failsToListWindows = false
        #expect(try model.focus(2, app) == window)
        #expect(model.tree == [window: .alive, otherWindow: .invisible])

        app.hidden = [2, 4]
        try model.refresh(app)
        #expect(model.tree == [window: .invisible, otherWindow: .invisible])
    }

    @Test func testTabGroupFirstSeenMinimized() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        app.minimized = [1, 2, 3]
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))
        #expect(model.tree.count == 3)

        app.minimized = []
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        app.select(2, in: "A")
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testTwoTabGroupFirstSeenMinimizedClosesFrontmostTab() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2]])
        app.minimized = [1, 2]
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.minimized = []
        try model.refresh(app)
        app.close(1)
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testMinimizeAndRestoreTabGroup() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2, 3]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.minimized = [1, 2, 3]
        try model.refresh(app)
        #expect(model.node(1) == node)

        app.minimized = []
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        for (closedTab, lastTabs): (UInt32, UInt32) in [(1, 2), (2, 3)] {
            app.close(closedTab)
            try model.refresh(app)
            #expect(model.node(lastTabs) == node)
            #expect(model.tree == [node: .alive])
        }
    }

    @Test func testMergeWindowIntoTabGroup() throws {
        let app = FakeApp(windows: [3], tabGroups: ["A": [1, 2]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.tabGroups["A"] = [1, 2, 3]
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        for tab: UInt32 in [2, 1] {
            app.close(tab)
            try model.refresh(app)
        }
        #expect(model.node(3) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testWindowMergedIntoTabGroupBetweenWindowListAndTabBarReads() throws {
        let app = FakeApp(windows: [3], tabGroups: ["A": [1, 2]])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        try model.refresh(app, afterListingWindows: { app.tabGroups["A"] = [1, 2, 3] })
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        for tab: UInt32 in [2, 1] {
            app.close(tab)
            try model.refresh(app)
            #expect(model.tree == [node: .alive])
        }
        #expect(model.node(3) == node)
    }

    @Test func testFrontmostTabOfTwoTabGroupClosesBetweenAliveAndWindowListReads() throws {
        let app = FakeApp(windows: [5], tabGroups: ["A": [91, 88]])
        var model = Model()
        try model.refresh(app)
        let (node, other) = (try #require(model.node(91)), try #require(model.node(5)))

        try model.refresh(app, afterReadingAliveWindows: { app.close(91) })
        #expect(model.node(88) == node)
        #expect(model.tree == [node: .alive, other: .alive])

        try model.refresh(app)
        #expect(model.node(88) == node)
        #expect(model.tree == [node: .alive, other: .alive])
    }

    @Test func testFrontmostTabOfTwoTabGroupClosesBetweenWindowListAndTabBarReads() throws {
        let app = FakeApp(windows: [5], tabGroups: ["A": [91, 88]])
        var model = Model()
        try model.refresh(app)
        let (node, other) = (try #require(model.node(91)), try #require(model.node(5)))

        try model.refresh(app, afterListingWindows: { app.close(91) })
        try model.refresh(app)
        #expect(model.node(88) == node)
        #expect(model.tree == [node: .alive, other: .alive])
    }

    @Test func testFrontmostTabOfTwoTabGroupClosesBeforeLastTabIsListedNextToAnotherTabGroup() throws {
        let app = FakeApp(tabGroups: ["A": [91, 88], "B": [5, 6]])
        var model = Model()
        try model.refresh(app)
        let (node, other) = (try #require(model.node(91)), try #require(model.node(5)))
        let windowServerCalls = app.windowServerCalls

        try model.refresh(app, afterReadingAliveWindows: {
            app.close(91)
            app.hidden = [88]
        })
        #expect(model.tree == [node: .invisible, other: .alive])
        #expect(app.windowServerCalls == windowServerCalls)

        app.hidden = []
        try model.refresh(app)
        #expect(model.node(88) == node)
        #expect(model.tree == [node: .alive, other: .alive])
    }

    @Test func testWindowUnlistedARefreshBeforeItsNewTabIsListed() throws {
        let app = FakeApp(windows: [1, 5])
        var model = Model()
        try model.refresh(app)
        let (node, other) = (try #require(model.node(1)), try #require(model.node(5)))

        app.tabGroups["A"] = [2, 1]
        try model.refresh(app)
        #expect(model.tree == [node: .invisible, other: .alive])

        app.windows.insert(2)
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive, other: .alive])
    }

    @Test func testTwoNewTabsBeforeRefresh() throws {
        let app = FakeApp(windows: [1])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.newTab(2, in: "A", of: 1)
        app.newTab(3, in: "A", of: 2)
        app.tabGroups["A"]?.append(1)
        try model.refresh(app)
        #expect(model.node(3) == node)
        #expect(model.tree == [node: .alive])

        for frontmostTab: UInt32 in [2, 1] {
            app.select(frontmostTab, in: "A")
            try model.refresh(app)
            #expect(model.node(frontmostTab) == node)
            #expect(model.tree == [node: .alive])
        }
    }

    @Test func testMergeTwoTabGroups() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2], "B": [3, 4]])
        var model = Model()
        try model.refresh(app)
        let a = try #require(model.node(1))

        app.tabGroups = ["A": [1, 2, 3, 4]]
        try model.refresh(app)
        #expect(model.tree == [a: .alive])

        for tab: UInt32 in [1, 2, 4] {
            app.close(tab)
            try model.refresh(app)
            #expect(model.tree == [a: .alive])
        }
        #expect(model.node(3) == a)
    }

    @Test func testMergeAllWindowsAfterRestore() throws {
        let app = FakeApp(windows: [1, 2, 3])
        app.minimized = [1]
        var model = Model()
        try model.refresh(app)
        app.minimized = []
        try model.refresh(app)
        let node = try #require(model.node(3))

        app.tabGroups["A"] = [3, 1, 2]
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        app.select(2, in: "A")
        try model.refresh(app)
        #expect(model.node(2) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testWindowsJoinTwoTabGroupsInOneRefresh() throws {
        let app = FakeApp(windows: [3, 6], tabGroups: ["A": [1, 2], "B": [4, 5]])
        var model = Model()
        try model.refresh(app)
        let (a, b) = (try #require(model.node(1)), try #require(model.node(4)))

        app.tabGroups = ["A": [3, 1, 2], "B": [4, 5, 6]]
        try model.refresh(app)
        #expect(model.node(3) == a)
        #expect(model.node(4) == b)
        #expect(model.tree == [a: .alive, b: .alive])
    }

    @Test func testDragFrontmostTabOfTwoTabGroupIntoBackgroundOfAnotherTabGroup() throws {
        let app = FakeApp(tabGroups: ["A": [1, 2], "B": [3, 4]])
        var model = Model()
        try model.refresh(app)
        let (a, b) = (try #require(model.node(1)), try #require(model.node(3)))

        app.tabGroups = ["A": [2], "B": [3, 4, 1]]
        try model.refresh(app)
        #expect(model.node(2) == a)
        #expect(model.node(3) == b)
        #expect(model.tree == [a: .alive, b: .alive])
    }

    @Test func testFocusMergedBackgroundTab() throws {
        let app = FakeApp(windows: [1, 2])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))

        app.tabGroups["A"] = [1, 2]
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        #expect(model.node(2) != nil)
        app.select(2, in: "A")
        #expect(try model.focus(2, app) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testFocusMergedBackgroundTabBeforeAppListsIt() throws {
        let app = FakeApp(windows: [1, 2])
        var model = Model()
        try model.refresh(app)
        let node = try #require(model.node(1))
        app.tabGroups["A"] = [1, 2]
        try model.refresh(app)

        #expect(try model.focus(2, app) == nil)
        try model.refresh(app)
        #expect(model.tree == [node: .alive])

        app.select(2, in: "A")
        #expect(try model.focus(2, app) == node)
        #expect(model.tree == [node: .alive])
    }

    @Test func testFocusFollowsBackgroundTabThatBecameFrontmost() {
        var mapping = nodes(["a": 1, "b": 2])
        #expect(takeOverTabGroupNodes([("b", 1)], &mapping, focusedNode: "a") == "b")
        #expect(mapping.forward == ["b": 1])
    }

    @Test func testTabGroupNodeKeepsFocus() {
        var mapping = nodes(["a": 1, "b": 2])
        #expect(takeOverTabGroupNodes([("b", 1)], &mapping, focusedNode: "b") == nil)
        #expect(takeOverTabGroupNodes([("b", 2)], &mapping, focusedNode: "c") == nil)
        #expect(takeOverTabGroupNodes([("b", 1)], &mapping, focusedNode: nil) == nil)
    }

    @Test func testFocusFollowsTabDraggedIntoAnotherTabGroup() {
        var mapping = nodes(["a": 1, "b": 3, "c": 2])
        #expect(takeOverTabGroupNodes([("a", 2), ("b", 1)], &mapping, focusedNode: "a") == "b")
        #expect(mapping.forward == ["a": 2, "b": 1])
    }
}

private func nodes(_ mapping: [String: UInt32]) -> BiDictionary<String, UInt32> {
    var result = BiDictionary<String, UInt32>()
    for (node, windowId) in mapping {
        result.put(node, windowId)
    }
    return result
}

private final class FakeApp: NativeTabsAx {
    var windows: Set<UInt32>
    var tabGroups: [String: [UInt32]]
    var hidden: Set<UInt32> = []
    var minimized: Set<UInt32> = []
    var failsToListWindows = false
    var detachedTabBars: Set<String> = []
    var unreadableTabBars: Set<String> = []
    var windowServerFails = false
    private(set) var windowServerCalls = 0
    var isAxBlank = false
    var axCalls = 0
    var cancelAfter: Int? = nil

    init(windows: Set<UInt32> = [], tabGroups: [String: [UInt32]] = [:]) {
        self.windows = windows.union(tabGroups.values.joined())
        self.tabGroups = tabGroups
    }

    var listedWindowIds: Set<UInt32>? {
        if failsToListWindows { return nil }
        if isAxBlank { return [] }
        return windows.subtracting(hidden).subtracting(backgroundTabs.filter { !minimized.contains($0) })
    }

    private var backgroundTabs: [UInt32] { tabGroups.values.filter { $0.count > 1 }.flatMap { $0.dropFirst() } }

    func newTab(_ tab: UInt32, in tabGroup: String, of window: UInt32) {
        windows.insert(tab)
        tabGroups[tabGroup] = [tab, window]
    }

    func select(_ tab: UInt32, in tabGroup: String) {
        tabGroups[tabGroup] = [tab] + (tabGroups[tabGroup] ?? []).filter { $0 != tab }
    }

    func close(_ window: UInt32) {
        windows.remove(window)
        tearOut(window, from: nil)
    }

    func tearOut(_ tab: UInt32, from tabGroup: String?) {
        for (key, tabs) in tabGroups where tabGroup == nil || key == tabGroup {
            tabGroups[key] = tabs.filter { $0 != tab }
        }
    }

    private func tick() throws {
        if let cancelAfter, axCalls >= cancelAfter { throw CancellationError() }
        axCalls += 1
    }

    private func liveTabs(_ tabBar: String) -> [UInt32]? {
        guard !isAxBlank, !unreadableTabBars.contains(tabBar), let tabs = tabGroups[tabBar], tabs.count > 1 else { return nil }
        return tabs
    }

    func isStandardWindow(_ windowId: UInt32) throws -> Bool {
        try tick()
        return !minimized.contains(windowId)
    }

    func tabBar(ofWindow windowId: UInt32) throws -> String? {
        try tick()
        return tabGroups.keys.first { liveTabs($0)?.first == windowId }
    }

    func host(of tabBar: String) throws -> UInt32? {
        try tick()
        return detachedTabBars.contains(tabBar) ? nil : liveTabs(tabBar)?.first
    }

    func tabCount(of tabBar: String) throws -> Int {
        try tick()
        return liveTabs(tabBar)?.count ?? 0
    }

    func isAlive(_ windowId: UInt32) throws -> Bool {
        try tick()
        return !isAxBlank && windows.contains(windowId)
    }

    func orderedInWindowIds() throws -> Set<UInt32>? {
        windowServerCalls += 1
        return windowServerFails ? nil : windows.subtracting(backgroundTabs).subtracting(minimized)
    }
}

private struct Model: Equatable {
    var windows: [UInt32: NativeTab<String>?] = [:]
    var mapping: [Int: UInt32] = [:]
    var focusedNode: Int? = nil
    private var nodeCount = 0

    func node(_ windowId: UInt32) -> Int? { mapping.first { $0.value == windowId }?.key }

    private(set) var tree: [Int: WindowLifeStatus] = [:]

    mutating func refresh(
        _ app: FakeApp,
        isScreenLocked: Bool = false,
        afterReadingAliveWindows: () -> () = {},
        afterListingWindows: () -> () = {},
    ) throws {
        var aliveOrInvisible = windows
        if !isScreenLocked {
            aliveOrInvisible = aliveOrInvisible.filter { !app.isAxBlank && app.windows.contains($0.key) }
        }
        afterReadingAliveWindows()
        let listedWindowIds = app.listedWindowIds
        afterListingWindows()
        for id in listedWindowIds ?? [] where aliveOrInvisible[id] == nil {
            aliveOrInvisible[id] = .some(nil)
        }
        let nativeTabs = isScreenLocked ? nil : try observeNativeTabs(
            previous: windows.compactMapValues { $0 },
            aliveWindowIds: aliveOrInvisible.keys.toSet(),
            listedWindowIds: listedWindowIds,
            app,
        )
        let lifeStatuses = nativeTabs?.commit(to: &aliveOrInvisible, \.self)
            ?? aliveOrInvisible.keys.associate { listedWindowIds?.contains($0) == true ? .alive : .invisible }
        windows = aliveOrInvisible

        var bidi = BiDictionary<Int, UInt32>()
        for (node, windowId) in mapping {
            bidi.put(node, windowId)
        }
        let takeovers = (nativeTabs?.takeovers ?? []).map { (tabGroupNode: getOrRegisterNode($0.from, &bidi), frontmostTabId: $0.to) }
        if let node = takeOverTabGroupNodes(takeovers, &bidi, focusedNode: focusedNode) {
            focusedNode = node
        }
        tree = [:]
        for (id, lifeStatus) in lifeStatuses {
            tree[getOrRegisterNode(id, &bidi)] = lifeStatus
        }
        mapping = bidi.forward
    }

    mutating func focus(_ windowId: UInt32, _ app: FakeApp) throws -> Int? {
        if node(windowId).flatMap({ tree[$0] }) == nil {
            if windows[windowId] == nil { windows[windowId] = .some(nil) }
            try refresh(app)
            if node(windowId).flatMap({ tree[$0] }) == nil { return nil }
        }
        focusedNode = node(windowId)
        return focusedNode
    }

    private mutating func getOrRegisterNode(_ windowId: UInt32, _ mapping: inout BiDictionary<Int, UInt32>) -> Int {
        if let existing = mapping.backward[windowId] { return existing }
        nodeCount += 1
        mapping.put(nodeCount, windowId)
        return nodeCount
    }
}
