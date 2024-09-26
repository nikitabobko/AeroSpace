@testable import AppBundle
import Common
import XCTest

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        assertNotNil(parseCommand("list-workspaces --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --all --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --visible").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --visible").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --monitor focused").cmdOrNil)
        assertNil(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil)
        assertEquals(parseCommand("list-workspaces --all --format %{workspace} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
    }
}
