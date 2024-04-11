import XCTest
import Nimble
@testable import AppBundle
import Common

final class SplitArgsTest: XCTestCase {
    func testSplit() {
        testSucSplit("echo foo", expected: ["echo", "foo"])
        testSucSplit("echo 'foo'", expected: ["echo", "foo"])
        testSucSplit("'echo' foo", expected: ["echo", "foo"])
        testSucSplit("echo \"'\"", expected: ["echo", "'"])
        testSucSplit("echo '\"'", expected: ["echo", "\""])
        testSucSplit("  echo '  foo bar'", expected: ["echo", "  foo bar"])

        testFailSplit("echo 'foo")
        testFailSplit("echo foo'")
    }
}

private func testSucSplit(_ str: String, expected: [String]) {
    let result = str.splitArgs()
    switch result {
        case .success(let actual):
            expect(actual) == expected
        case .failure:
            XCTFail("\(str) split is not successful")
    }
}

private func testFailSplit(_ str: String) {
    let result = str.splitArgs()
    switch result {
        case .success:
            XCTFail("\(str) is expected to fail to split")
        case .failure:
            break
    }
}
