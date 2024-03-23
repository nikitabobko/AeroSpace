import XCTest
import Common
import Nimble
@testable import AppBundle

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-workspaces --all").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --all --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --focused --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --focused --all").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --monitor focused").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --focused --monitor 2").cmdOrNil).to(beNil())
    }
}
