@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListWorkspacesTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNotNil(parseCommand("list-workspaces --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --all --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --visible").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --monitor focused").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --all --format %{workspace}").cmdOrNil)
        assertEquals(parseCommand("list-workspaces --all --format %{workspace} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(parseCommand("list-workspaces --empty").errorOrNil, "Mandatory option is not specified (--all|--focused|--monitor)")
        assertEquals(parseCommand("list-workspaces --all --focused --monitor mouse").errorOrNil, "ERROR: Conflicting options: --all, --focused, --monitor")
    }

    func testWorkspaceRootOrientationVariable() {
        // Test horizontal workspace root orientation
        Workspace.get(byName: name).rootTilingContainer.apply {
            $0._orientation = .h
            let workspace = Workspace.get(byName: name)
            let workspaces = [AeroObj.workspace(workspace)]
            assertEquals(
                workspaces.format([.interVar("workspace-root-container-orientation")]),
                .success(["horizontal"])
            )
        }

        // Test vertical workspace root orientation
        Workspace.get(byName: name).rootTilingContainer.apply {
            $0._orientation = .v
            let workspace = Workspace.get(byName: name)
            let workspaces = [AeroObj.workspace(workspace)]
            assertEquals(
                workspaces.format([.interVar("workspace-root-container-orientation")]),
                .success(["vertical"])
            )
        }

        // Test combined format with orientation and layout
        Workspace.get(byName: name).rootTilingContainer.apply {
            $0._orientation = .h
            let workspace = Workspace.get(byName: name)
            let workspaces = [AeroObj.workspace(workspace)]
            assertEquals(
                workspaces.format([
                    .interVar("workspace"),
                    .literal(" | "),
                    .interVar("workspace-root-container-orientation"),
                    .literal(" | "),
                    .interVar("workspace-root-container-layout")
                ]),
                .success(["\(name) | horizontal | h_tiles"])
            )
        }
    }
}
