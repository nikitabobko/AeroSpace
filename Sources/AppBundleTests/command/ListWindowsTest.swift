import XCTest
import Common
import Nimble
@testable import AppBundle

final class ListWindowsTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-windows --pid 1").errorOrNil).to(equal("Specified flags require explicit (--workspace|--monitor)"))
        expect(parseCommand("list-windows --workspace M --pid 1").errorOrNil).to(beNil())
        expect(parseCommand("list-windows --pid 1 --focused").errorOrNil).to(equal("Specified flags require explicit (--workspace|--monitor)"))
        expect(parseCommand("list-windows --pid 1 --all").errorOrNil).to(equal("Specified flags require explicit (--workspace|--monitor)"))
        expect(parseCommand("list-windows --all").errorOrNil).to(beNil())
        expect(parseCommand("list-windows --all --workspace M").errorOrNil).to(equal("Conflicting options: --all, --workspace"))
        expect(parseCommand("list-windows --all --focused").errorOrNil).to(equal("Conflicting options: --focused, --all"))
    }
}
