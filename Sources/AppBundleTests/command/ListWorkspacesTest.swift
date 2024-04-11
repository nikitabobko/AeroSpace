import XCTest
import Common
import Nimble
@testable import AppBundle

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-workspaces --all").cmdOrNil) != nil
        expect(parseCommand("list-workspaces --all --visible").cmdOrNil) == nil
        expect(parseCommand("list-workspaces --focused --visible").cmdOrNil) == nil
        expect(parseCommand("list-workspaces --focused --all").cmdOrNil) == nil
        expect(parseCommand("list-workspaces --visible").cmdOrNil) == nil
        expect(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil) != nil
        expect(parseCommand("list-workspaces --monitor focused").cmdOrNil) != nil
        expect(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil) == nil
    }
}
