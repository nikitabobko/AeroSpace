import XCTest
import Common
import Nimble
@testable import AeroSpace_Debug

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-workspaces --all").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --all --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --focused --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --focused --all").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --visible").cmdOrNil).to(beNil())
        expect(parseCommand("list-workspaces --visible --on-monitors 2").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --on-monitors focused").cmdOrNil).toNot(beNil())
        expect(parseCommand("list-workspaces --focused --on-monitors 2").cmdOrNil).to(beNil())
    }
}
