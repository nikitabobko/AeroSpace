import XCTest
@testable import AeroSpace_Debug

final class CommandTest: XCTestCase {
    func testExecAndWait() async throws {
        let before = Date().timeIntervalSince1970
        await ExecAndWaitCommand(bashCommand: "sleep 2").runWithoutRefresh()
        let after = Date().timeIntervalSince1970
        XCTAssertTrue((after - before) > 1)
    }

    func testExecAndForget() async throws {
        let before = Date().timeIntervalSince1970
        await ExecAndForgetCommand(bashCommand: "sleep 2").runWithoutRefresh()
        let after = Date().timeIntervalSince1970
        XCTAssertTrue((after - before) < 1)
    }
}
