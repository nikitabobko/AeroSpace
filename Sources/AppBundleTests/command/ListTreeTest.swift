@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListTreeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNotNil(parseCommand("list-tree --focused").cmdOrNil)
        assertNotNil(parseCommand("list-tree --workspace a").cmdOrNil)
        assertNotNil(parseCommand("list-tree --workspace a --json").cmdOrNil)
        assertEquals(parseCommand("list-tree").errorOrNil, "Mandatory option is not specified (--focused|--workspace)")
        assertEquals(
            parseCommand("list-tree --focused --workspace a").errorOrNil,
            "ERROR: Conflicting options: --focused, --workspace",
        )
    }

    /// h_tiles(1, v_tiles(2, 3))
    private func nestedWorkspace() -> Workspace {
        Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    TestWindow.new(id: 3, parent: $0)
                }
            }
        }
    }

    func testRunNested() async {
        _ = nestedWorkspace()
        let result = await parseCommand("list-tree --workspace a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [
            "workspace a",
            "  h_tiles",
            "    window 1",
            "    v_tiles",
            "      window 2",
            "      window 3",
        ])
    }

    /// Floating windows are not part of the tiling tree
    func testRunIgnoresFloatingWindows() async {
        let workspace = Workspace.get(byName: "a")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer)
        let result = await parseCommand("list-tree --workspace a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["workspace a", "  h_tiles", "    window 1"])
    }

    func testRunEmptyWorkspace() async {
        _ = Workspace.get(byName: "a")
        let result = await parseCommand("list-tree --workspace a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["workspace a", "  h_tiles"])
    }

    func testRunSeveralWorkspacesAreSorted() async {
        TestWindow.new(id: 1, parent: Workspace.get(byName: "b").rootTilingContainer)
        TestWindow.new(id: 2, parent: Workspace.get(byName: "a").rootTilingContainer)
        let result = await parseCommand("list-tree --workspace b a").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [
            "workspace a",
            "  h_tiles",
            "    window 2",
            "workspace b",
            "  h_tiles",
            "    window 1",
        ])
    }

    func testRunJson() async {
        _ = nestedWorkspace()
        let result = await parseCommand("list-tree --workspace a --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["""
            [
              {
                "root" : {
                  "children" : [
                    {
                      "type" : "window",
                      "window-id" : 1
                    },
                    {
                      "children" : [
                        {
                          "type" : "window",
                          "window-id" : 2
                        },
                        {
                          "type" : "window",
                          "window-id" : 3
                        }
                      ],
                      "layout" : "v_tiles",
                      "type" : "tiling-container"
                    }
                  ],
                  "layout" : "h_tiles",
                  "type" : "tiling-container"
                },
                "workspace" : "a"
              }
            ]
            """])
    }
}
