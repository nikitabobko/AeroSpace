import XCTest
import Common
import Nimble
@testable import AeroSpace_Debug

final class ListWindowsTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-windows --pid 1").errorOrNil).to(equal("Specified flags require explicit (--on-workspaces|--on-monitor)"))
        expect(parseCommand("list-windows --on-workspaces M --pid 1").errorOrNil).to(beNil())
        expect(parseCommand("list-windows --pid 1 --focused").errorOrNil).to(equal("Specified flags require explicit (--on-workspaces|--on-monitor)"))
        expect(parseCommand("list-windows --pid 1 --all").errorOrNil).to(equal("Specified flags require explicit (--on-workspaces|--on-monitor)"))
        expect(parseCommand("list-windows --all").errorOrNil).to(beNil())
        expect(parseCommand("list-windows --all --on-workspaces M").errorOrNil).to(equal("Conflicting options: --all, --on-workspaces"))
        expect(parseCommand("list-windows --all --focused").errorOrNil).to(equal("Conflicting options: --focused, --all"))
    }
}
