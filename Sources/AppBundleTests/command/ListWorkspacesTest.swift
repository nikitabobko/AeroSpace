import XCTest
import Common
import PowerAssert
@testable import AppBundle

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        #assert(parseCommand("list-workspaces --all").cmdOrNil != nil)
        #assert(parseCommand("list-workspaces --all --visible").cmdOrNil == nil)
        #assert(parseCommand("list-workspaces --focused --visible").cmdOrNil == nil)
        #assert(parseCommand("list-workspaces --focused --all").cmdOrNil == nil)
        #assert(parseCommand("list-workspaces --visible").cmdOrNil == nil)
        #assert(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil != nil)
        #assert(parseCommand("list-workspaces --monitor focused").cmdOrNil != nil)
        #assert(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil == nil)
    }
}
