import XCTest
import Common
import Nimble
@testable import AppBundle

final class ListWindowsTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-windows --pid 1").errorOrNil) == "Specified flags require explicit (--workspace|--monitor)"
        expect(parseCommand("list-windows --workspace M --pid 1").errorOrNil) == nil
        expect(parseCommand("list-windows --pid 1 --focused").errorOrNil) == "Specified flags require explicit (--workspace|--monitor)"
        expect(parseCommand("list-windows --pid 1 --all").errorOrNil) == "Specified flags require explicit (--workspace|--monitor)"
        expect(parseCommand("list-windows --all").errorOrNil) == nil
        expect(parseCommand("list-windows --all --workspace M").errorOrNil) == "Conflicting options: --all, --workspace"
        expect(parseCommand("list-windows --all --focused").errorOrNil) == "Conflicting options: --focused, --all"
    }
}
