import XCTest
import Common
import PowerAssert
@testable import AppBundle

final class ListWindowsTest: XCTestCase {
    func testParse() {
        #assert(parseCommand("list-windows --pid 1").errorOrNil == "Specified flags require explicit (--workspace|--monitor)")
        #assert(parseCommand("list-windows --workspace M --pid 1").errorOrNil == nil)
        #assert(parseCommand("list-windows --pid 1 --focused").errorOrNil == "Specified flags require explicit (--workspace|--monitor)")
        #assert(parseCommand("list-windows --pid 1 --all").errorOrNil == "Specified flags require explicit (--workspace|--monitor)")
        #assert(parseCommand("list-windows --all").errorOrNil == nil)
        #assert(parseCommand("list-windows --all --workspace M").errorOrNil == "Conflicting options: --all, --workspace")
        #assert(parseCommand("list-windows --all --focused").errorOrNil == "Conflicting options: --focused, --all")
    }
}
