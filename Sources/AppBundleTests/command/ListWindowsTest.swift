@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListWindowsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseCommand("list-windows --pid 1").errorOrNil, "Mandatory option is not specified (--focused|--all|--monitor|--workspace)")
        assertNil(parseCommand("list-windows --workspace M --pid 1").errorOrNil)
        assertEquals(parseCommand("list-windows --pid 1 --focused").errorOrNil, "--focused conflicts with other \"filtering\" flags")
        assertEquals(parseCommand("list-windows --pid 1 --all").errorOrNil, "--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias")
        assertNil(parseCommand("list-windows --all").errorOrNil)
        assertEquals(parseCommand("list-windows --all --workspace M").errorOrNil, "ERROR: Conflicting options: --all, --workspace")
        assertEquals(parseCommand("list-windows --all --focused").errorOrNil, "ERROR: Conflicting options: --all, --focused")
        assertEquals(parseCommand("list-windows --all --count --format %{window-title}").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(
            parseCommand("list-windows --all --focused --monitor mouse").errorOrNil,
            "ERROR: Conflicting options: --all, --focused")
        assertEquals(
            parseCommand("list-windows --all --focused --monitor mouse --workspace focused").errorOrNil,
            "ERROR: Conflicting options: --all, --focused, --workspace")
        assertEquals(
            parseCommand("list-windows --all --workspace focused").errorOrNil,
            "ERROR: Conflicting options: --all, --workspace")
        assertNil(parseCommand("list-windows --monitor mouse").errorOrNil)

        // --json
        assertEquals(parseCommand("list-windows --all --count --json").errorOrNil, "ERROR: Conflicting options: --count, --json")
        assertEquals(parseCommand("list-windows --all --format '%{right-padding}' --json").errorOrNil, "%{right-padding} interpolation variable is not allowed when --json is used")
        assertEquals(parseCommand("list-windows --all --format '%{window-title} |' --json").errorOrNil, "Only interpolation variables and spaces are allowed in \'--format\' when \'--json\' is used")
        assertNil(parseCommand("list-windows --all --format '%{window-title}' --json").errorOrNil)
    }

    func testInterpolationVariablesConsistency() {
        for kind in AeroObjKind.allCases {
            switch kind {
                case .window:
                    assertTrue(FormatVar.WindowFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "window-") })
                case .app:
                    assertTrue(FormatVar.AppFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "app-") })
                case .workspace:
                    assertTrue(FormatVar.WorkspaceFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "workspace") })
                case .monitor:
                    assertTrue(FormatVar.MonitorFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "monitor-") })
            }
        }
    }

    func testFormat() {
        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows = [
                AeroObj.window(.forTest(window: TestWindow.new(id: 2, parent: $0), title: "non-empty")),
                AeroObj.window(.forTest(window: TestWindow.new(id: 1, parent: $0), title: "")),
            ]
            assertSucc(windows.format([.interVar(.formatVar(.window(.windowTitle)))]), ["non-empty", ""])
        }

        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows = [
                AeroObj.window(.forTest(window: TestWindow.new(id: 2, parent: $0), title: "non-empty")),
                AeroObj.window(.forTest(window: TestWindow.new(id: 10, parent: $0), title: "")),
            ]
            assertSucc(windows.format([.interVar(.formatVar(.window(.windowId))), .interVar(.plainInterVar(.rightPadding)), .interVar(.formatVar(.window(.windowTitle)))]), ["2 non-empty", "10"])
        }

        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows = [
                AeroObj.window(.forTest(window: TestWindow.new(id: 2, parent: $0), title: "title1")),
                AeroObj.window(.forTest(window: TestWindow.new(id: 10, parent: $0), title: "title2")),
            ]
            assertSucc(windows.format([.interVar(.formatVar(.window(.windowId))), .interVar(.plainInterVar(.rightPadding)), .literal(" | "), .interVar(.formatVar(.window(.windowTitle)))]), ["2  | title1", "10 | title2"])
        }
    }

    func testRunFocusedNoWindow() async {
        let result = await parseCommand("list-windows --focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
        assertEquals(result.stdout, [])
    }

    func testRunFocusedHappy() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }
        let result = await parseCommand("list-windows --focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1"])
    }

    func testRunAll() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-windows --all --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1", "2"])
    }

    func testRunCount() async {
        let workspace = Workspace.get(byName: "a")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 3, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-windows --all --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["3"])
    }

    func testRunJson() async {
        TestWindow.new(id: 7, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-windows --all --format '%{window-id}' --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([["window-id": 7]])
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [expected])
    }

    func testRunFilterByWorkspaceName() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        let result = await parseCommand("list-windows --workspace a --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunFilterByWorkspaceFocused() async {
        let workspaceA = Workspace.get(byName: "a")
        TestWindow.new(id: 1, parent: workspaceA.rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        assertEquals(workspaceA.focusWorkspace(), true)
        let result = await parseCommand("list-windows --workspace focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunFilterByWorkspaceVisible() async {
        let workspaceA = Workspace.get(byName: "a")
        TestWindow.new(id: 1, parent: workspaceA.rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "b").rootTilingContainer)
        assertEquals(workspaceA.focusWorkspace(), true)
        let result = await parseCommand("list-windows --workspace visible --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunFilterByMonitor() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-windows --monitor focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunInvalidMonitor() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-windows --monitor 99 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid monitor ID: 99"])
    }

    func testRunFilterByPid() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let matching = await parseCommand("list-windows --monitor all --pid 0 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(matching.exitCode.rawValue, 0)
        assertEquals(matching.stdout, ["1"])

        let mismatching = await parseCommand("list-windows --monitor all --pid 9999 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(mismatching.exitCode.rawValue, 0)
        assertEquals(mismatching.stdout, [])
    }

    func testRunFilterByAppBundleId() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a").rootTilingContainer)
        let matching = await parseCommand("list-windows --monitor all --app-bundle-id bobko.AeroSpace.test-app --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(matching.exitCode.rawValue, 0)
        assertEquals(matching.stdout, ["1"])

        let mismatching = await parseCommand("list-windows --monitor all --app-bundle-id com.unknown.app --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(mismatching.exitCode.rawValue, 0)
        assertEquals(mismatching.stdout, [])
    }

    func testParseSortBy() {
        func sortByOf(_ args: [String]) -> [SortBy]? { (parseCommand(args).cmdOrNil as? ListWindowsCommand)?.args.sortBy }
        assertEquals(sortByOf(["list-windows", "--all"]), [])

        assertEquals(sortByOf(["list-windows", "--all", "--sort-by", "dfs"]), [.dfs])
        assertEquals(sortByOf(["list-windows", "--all", "--sort-by", "app-name", "window-title"]), [.appName, .windowTitle])
        assertEquals(sortByOf(["list-windows", "--all", "--sort-by", "window-id"]), [.windowId])
        assertEquals(sortByOf(["list-windows", "--all", "--sort-by", "window-title", "dfs", "app-name"]), [.windowTitle, .dfs, .appName])
        assertEquals(sortByOf(["list-windows", "--all", "--sort-by", "dfs", "--format", "%{window-id}"]), [.dfs])

        assertEquals(
            parseCommand("list-windows --all --sort-by bogus").errorOrNil,
            "ERROR: Can't parse 'bogus'.\n       Possible values: (dfs|app-name|window-title|window-id)")
        assertEquals(
            parseCommand("list-windows --all --sort-by dfs bogus").errorOrNil,
            "ERROR: Can't parse 'bogus'.\n       Possible values: (dfs|app-name|window-title|window-id)")
        assertEquals(
            parseCommand("list-windows --all --sort-by").errorOrNil,
            "ERROR: <sort-by>... is mandatory. Possible values: (dfs|app-name|window-title|window-id)")
        assertEquals(
            parseCommand("list-windows --all --count --sort-by dfs").errorOrNil,
            "ERROR: Conflicting options: --count, --sort-by")
    }

    func testRunSortByDfs() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 1, parent: $0)
            }
            TestWindow.new(id: 2, parent: $0)
        }
        Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 10, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }
        let result = await parseCommand("list-windows --all --sort-by dfs --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["3", "1", "2", "10", "4"])
    }

    func testRunSortByAppNameAndWindowTitleIsTheDefault() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 10, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        let expected = ["TestWindow(1)", "TestWindow(10)", "TestWindow(2)", "TestWindow(3)"]
        let explicit = await parseCommand("list-windows --all --sort-by app-name window-title --format '%{window-title}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(explicit.exitCode.rawValue, 0)
        assertEquals(explicit.stdout, expected)

        let implicit = await parseCommand("list-windows --all --format '%{window-title}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(implicit.exitCode.rawValue, 0)
        assertEquals(implicit.stdout, expected)
    }

    func testRunSortByAppName() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, app: TestApp(name: "Zulu"))
            TestWindow.new(id: 2, parent: $0, app: TestApp(name: "Mike"))
            TestWindow.new(id: 3, parent: $0, app: TestApp(name: "Alpha"))
        }
        let result = await parseCommand("list-windows --all --sort-by app-name --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["3", "2", "1"])
    }

    func testRunSortByAppNameTieBreaksByWindowId() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, app: TestApp(name: "Zulu"))
            TestWindow.new(id: 20, parent: $0, app: TestApp(name: "Alpha"))
            TestWindow.new(id: 3, parent: $0, app: TestApp(name: "Alpha"))
            TestWindow.new(id: 10, parent: $0, app: TestApp(name: "Zulu"))
        }
        let result = await parseCommand("list-windows --all --sort-by app-name --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["3", "20", "1", "10"])
    }

    func testRunSortByDfsDoesNotMutateTheTree() async {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 3, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
                TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 100, width: 100, height: 100))
            }
            TestWindow.new(id: 2, parent: $0, rect: Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 200))
        }
        workspace.floatingWindowsContainer.apply {
            TestWindow.new(id: 5, parent: $0, rect: Rect(topLeftX: 290, topLeftY: 10, width: 20, height: 20))
            TestWindow.new(id: 6, parent: $0, rect: Rect(topLeftX: 90, topLeftY: 10, width: 20, height: 20))
            TestWindow.new(id: 7, parent: $0, rect: Rect(topLeftX: 190, topLeftY: 10, width: 20, height: 20))
        }

        let treeBefore = workspace.layoutDescription
        let floatingBefore = workspace.floatingWindows.map(\.windowId)
        let allBefore = workspace.allLeafWindowsRecursive
        let idsBefore = allBefore.map(\.windowId)
        let parentsBefore = allBefore.map { ObjectIdentifier($0.parent.orDie()) }
        assertEquals(floatingBefore, [5, 6, 7])

        let result = await parseCommand("list-windows --all --sort-by dfs --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["6", "7", "5", "3", "1", "2"])

        assertEquals(workspace.layoutDescription, treeBefore)
        assertEquals(workspace.floatingWindows.map(\.windowId), floatingBefore)
        let allAfter = workspace.allLeafWindowsRecursive
        assertEquals(allAfter.map(\.windowId), idsBefore)
        assertEquals(allAfter.map { ObjectIdentifier($0.parent.orDie()) }, parentsBefore)
    }

    func testSortByDfsMatchesFocusDfsIndexInteractingIndices() async {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TestWindow.newTiled(id: 1, parent: $0, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 200))
            TestWindow.newTiled(id: 2, parent: $0, rect: Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 200))
            TestWindow.newTiled(id: 3, parent: $0, rect: Rect(topLeftX: 200, topLeftY: 0, width: 100, height: 200))
        }
        TestWindow.new(id: 5, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 105, topLeftY: 50, width: 20, height: 20))
        TestWindow.new(id: 6, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 170, topLeftY: 50, width: 20, height: 20))
        assertEquals(workspace.focusWorkspace(), true)

        let listed = await parseCommand("list-windows --workspace a --sort-by dfs --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(listed.exitCode.rawValue, 0)
        assertEquals(listed.stderr, [])
        assertEquals(listed.stdout, ["1", "5", "2", "6", "3"])

        for (index, windowId) in listed.stdout.enumerated() {
            let msg = "dfs-index \(index)"
            let result = await parseCommand("focus --dfs-index \(index)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            assertEquals(result.exitCode.rawValue, 0, additionalMsg: msg)
            assertEquals(result.stderr, [], additionalMsg: msg)
            assertEquals(focus.windowOrNil?.windowId.description, windowId, additionalMsg: msg)
        }
    }

    func testSortByDfsMatchesFocusDfsIndexAccordionParent() async {
        let workspace = Workspace.get(byName: "a")
        TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .v, .accordion, index: INDEX_BIND_LAST).apply { accordion in
            accordion.lastAppliedLayoutVirtualRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 200)
            TestWindow.newTiled(id: 1, parent: accordion, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
            TestWindow.newTiled(id: 2, parent: accordion, rect: Rect(topLeftX: 0, topLeftY: 100, width: 100, height: 100)).markAsMostRecentChild()
        }
        TestWindow.new(id: 5, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 10, topLeftY: 10, width: 20, height: 20))
        TestWindow.new(id: 6, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 10, topLeftY: 160, width: 20, height: 20))
        assertEquals(workspace.focusWorkspace(), true)

        let listed = await parseCommand("list-windows --workspace a --sort-by dfs --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(listed.exitCode.rawValue, 0)
        assertEquals(listed.stderr, [])
        assertEquals(listed.stdout, ["5", "1", "2", "6"])

        for (index, windowId) in listed.stdout.enumerated() {
            let msg = "dfs-index \(index)"
            let result = await parseCommand("focus --dfs-index \(index)").cmdOrDie.run(.defaultEnv, .emptyStdin)
            assertEquals(result.exitCode.rawValue, 0, additionalMsg: msg)
            assertEquals(result.stderr, [], additionalMsg: msg)
            assertEquals(focus.windowOrNil?.windowId.description, windowId, additionalMsg: msg)
        }
    }

    func testRunSortByDfsPutsNonTraversedWindowsLast() async {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 1, parent: $0)
        }
        TestWindow.new(id: 9, parent: workspace.macOsNativeFullscreenWindowsContainer)
        TestWindow.new(id: 8, parent: workspace.macOsNativeHiddenAppsWindowsContainer)

        let result = await parseCommand("list-windows --all --sort-by dfs --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["3", "1", "8", "9"])
    }

    func testRunSortByDfsThenSecondaryKey() async {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 1, parent: $0)
        }
        TestWindow.new(id: 8, parent: workspace.macOsNativeFullscreenWindowsContainer)
        TestWindow.new(id: 20, parent: workspace.macOsNativeHiddenAppsWindowsContainer)

        let byTitle = await parseCommand("list-windows --all --sort-by dfs window-title --format '%{window-title}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(byTitle.exitCode.rawValue, 0)
        assertEquals(byTitle.stdout, ["TestWindow(3)", "TestWindow(1)", "TestWindow(20)", "TestWindow(8)"])

        let byAppName = await parseCommand("list-windows --all --sort-by dfs app-name --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(byAppName.exitCode.rawValue, 0)
        assertEquals(byAppName.stdout, ["3", "1", "8", "20"])
    }

    func testRunSortByWindowTitleWithTitlelessFormat() async {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 10, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        let result = await parseCommand("list-windows --all --sort-by window-title --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1", "10", "2", "3"])
    }
}
