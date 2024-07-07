import XCTest
import Common
@testable import AppBundle

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
    }
}
