import XCTest
@testable import AeroSpace_Debug

final class ExecCommandTest: XCTestCase {
    func testExecAndWait() {
        let before = Date().timeIntervalSince1970
        ExecAndWaitCommand(bashCommand: "sleep 2").testRun()
        let after = Date().timeIntervalSince1970
        XCTAssertTrue((after - before) > 1)
    }

    func testExecAndForget() {
        let before = Date().timeIntervalSince1970
        ExecAndForgetCommand(bashCommand: "sleep 2").testRun()
        let after = Date().timeIntervalSince1970
        XCTAssertTrue((after - before) < 1)
    }
}
