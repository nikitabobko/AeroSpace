import XCTest
import Common

// Because XCTAssertEqual default messages are unreadable!
func assertFailure<T, F>(_ r: Result<T, F>, file: String = #file, line: Int = #line) {
    switch r {
        case .success: failExpectedActual("Result.failure", r, file: file, line: line)
        case .failure: break
    }
}

func assertEquals<T>( _ actual: T, _ expected: T, file: String = #file, line: Int = #line) where T: Equatable {
    if actual != expected {
        failExpectedActual(expected, actual, file: file, line: line)
    }
}

private func failExpectedActual( _ expected: Any, _ actual: Any, file: String = #file, line: Int = #line) {
    XCTFail(
        """

        Assertion failed at \(file):\(line)
            Expected:
                \(expected)
            Actual:
                \(actual)
        """
    )
}
