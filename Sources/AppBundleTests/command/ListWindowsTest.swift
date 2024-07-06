import XCTest
import Common
import Nimble
@testable import AppBundle

final class ListWindowsTest: XCTestCase {
    func testParse() {
        expect(parseCommand("list-windows --pid 1").errorOrNil) == "Mandatory option is not specified (--focused|--all|--monitor|--workspace)"
        expect(parseCommand("list-windows --workspace M --pid 1").errorOrNil) == nil
        expect(parseCommand("list-windows --pid 1 --focused").errorOrNil) == "--focused conflicts with \"filtering\" flags"
        expect(parseCommand("list-windows --pid 1 --all").errorOrNil) == "--all conflicts with \"filtering\" flags. Please use '--monitor all'"
        expect(parseCommand("list-windows --all").errorOrNil) == nil
        expect(parseCommand("list-windows --all --workspace M").errorOrNil) == "Conflicting options: --workspace, --all"
        expect(parseCommand("list-windows --all --focused").errorOrNil) == "Conflicting options: --focused, --all"
    }
}
