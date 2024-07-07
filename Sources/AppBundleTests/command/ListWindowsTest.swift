import XCTest
import Common
@testable import AppBundle

final class ListWindowsTest: XCTestCase {
    func testParse() {
        assertEquals(parseCommand("list-windows --pid 1").errorOrNil, "Mandatory option is not specified (--focused|--all|--monitor|--workspace)")
        assertNil(parseCommand("list-windows --workspace M --pid 1").errorOrNil)
        assertEquals(parseCommand("list-windows --pid 1 --focused").errorOrNil, "--focused conflicts with \"filtering\" flags")
        assertEquals(parseCommand("list-windows --pid 1 --all").errorOrNil, "--all conflicts with \"filtering\" flags. Please use '--monitor all'")
        assertNil(parseCommand("list-windows --all").errorOrNil)
        assertEquals(parseCommand("list-windows --all --workspace M").errorOrNil, "Conflicting options: --workspace, --all")
        assertEquals(parseCommand("list-windows --all --focused").errorOrNil, "Conflicting options: --focused, --all")
    }
}
