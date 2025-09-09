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

    func testParseValidLayoutOptions() {
        assertNil(parseCommand("list-windows --monitor all --layout accordion").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout tiles").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout horizontal").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout vertical").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout h_accordion").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout v_accordion").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout h_tiles").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout v_tiles").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout tiling").errorOrNil)
        assertNil(parseCommand("list-windows --monitor all --layout floating").errorOrNil)

        assertNil(parseCommand("list-windows --monitor mouse --layout floating").errorOrNil)
        assertNil(parseCommand("list-windows --workspace M --layout tiling").errorOrNil)
    }

    func testParseInvalidLayoutOptions() {
        assertEquals(parseCommand("list-windows --monitor all --layout invalid").errorOrNil, "ERROR: Failed to convert 'invalid' to 'LayoutDescription'")
        assertEquals(parseCommand("list-windows --all --layout tiles").errorOrNil, "--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias")
        assertEquals(parseCommand("list-windows --focused --layout tiling").errorOrNil, "--focused conflicts with other \"filtering\" flags")
    }

    func testFloatingLayoutFiltering() async throws {
        setupTestWorkspace()

        let lines = try await executeCommand("list-windows --monitor all --layout floating")

        // Should only contain the two floating windows
        assertEquals(lines.count, 2)
        assertTrue(lines.contains { $0.contains("2004") })
        assertTrue(lines.contains { $0.contains("2005") })
    }

    func testTilingLayoutFiltering() async throws {
        setupTestWorkspace()

        let lines = try await executeCommand("list-windows --monitor all --layout tiling")

        // Should contain the three tiling windows (tiles + accordion)
        assertEquals(lines.count, 3)
        assertTrue(lines.contains { $0.contains("2001") })
        assertTrue(lines.contains { $0.contains("2002") })
        assertTrue(lines.contains { $0.contains("2003") })
    }

    func testTilesLayoutFiltering() async throws {
        setupTestWorkspace()

        let lines = try await executeCommand("list-windows --monitor all --layout tiles")

        // Should contain the two tiles windows
        assertEquals(lines.count, 2)
        assertTrue(lines.contains { $0.contains("2001") })
        assertTrue(lines.contains { $0.contains("2002") })
    }

    func testAccordionLayoutFiltering() async throws {
        setupTestWorkspace()

        let lines = try await executeCommand("list-windows --monitor all --layout accordion")

        // Should contain the accordion window
        assertEquals(lines.count, 1)
        assertTrue(lines.contains { $0.contains("2003") })
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
                AeroObj.window(window: TestWindow.new(id: 2, parent: $0), title: "non-empty"),
                AeroObj.window(window: TestWindow.new(id: 1, parent: $0), title: ""),
            ]
            assertEquals(windows.format([.interVar("window-title")]), .success(["non-empty", ""]))
        }

        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows = [
                AeroObj.window(window: TestWindow.new(id: 2, parent: $0), title: "non-empty"),
                AeroObj.window(window: TestWindow.new(id: 10, parent: $0), title: ""),
            ]
            assertEquals(windows.format([.interVar("window-id"), .interVar("right-padding"), .interVar("window-title")]), .success(["2 non-empty", "10"]))
        }

        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows = [
                AeroObj.window(window: TestWindow.new(id: 2, parent: $0), title: "title1"),
                AeroObj.window(window: TestWindow.new(id: 10, parent: $0), title: "title2"),
            ]
            assertEquals(windows.format([.interVar("window-id"), .interVar("right-padding"), .literal(" | "), .interVar("window-title")]), .success(["2  | title1", "10 | title2"]))
        }
    }

    fileprivate func setupTestWorkspace() {
        let workspace = Workspace.get(byName: name)
        let rootContainer = workspace.rootTilingContainer

        // Create tiled windows (in tiling containers)
        let tilesContainer = TilingContainer.newHTiles(parent: rootContainer, adaptiveWeight: 1.0, index: 0)
        _ = TestWindow.new(id: 2001, parent: tilesContainer)
        _ = TestWindow.new(id: 2002, parent: tilesContainer)

        // Create accordion container with window
        let accordionContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .accordion, index: 1)
        _ = TestWindow.new(id: 2003, parent: accordionContainer)

        // Create floating windows (directly in workspace)
        _ = TestWindow.new(id: 2004, parent: workspace)
        _ = TestWindow.new(id: 2005, parent: workspace)
    }

    fileprivate func executeCommand(_ commandString: String) async throws -> [String] {
        let command = parseCommand(commandString).cmdOrDie
        let result = try await command.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode, 0)
        return result.stdout.filter { !$0.isEmpty }
    }
}
