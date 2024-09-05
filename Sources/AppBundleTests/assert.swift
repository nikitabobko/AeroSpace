import Common
import XCTest

// Because assertEquals default messages are unreadable!
func assertNotEquals<T>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) where T: Equatable {
    if actual == expected {
        failExpectedActual("not \(expected)", actual, file: file, line: line)
    }
}

func assertNil(_ actual: Any?, file: String = #file, line: Int = #line) {
    if let actual {
        failExpectedActual("nil", actual, file: file, line: line)
    }
}

func assertNotNil(_ actual: Any?, file: String = #file, line: Int = #line) {
    if actual == nil {
        failExpectedActual("not nil", "nil", file: file, line: line)
    }
}

func assertEquals<T>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) where T: Equatable {
    if actual != expected {
        failExpectedActual(expected, actual, file: file, line: line)
    }
}

func assertSucc<T>(_ actual: Result<T, some Any>, _ expected: T? = nil, file: String = #file, line: Int = #line) where T: Equatable {
    switch actual {
        case .failure: failExpectedActual("Result.success", actual, file: file, line: line)
        case .success(let actual):
            if let expected {
                assertEquals(actual, expected, file: file, line: line)
            }
    }
}
func assertFail<F>(_ actual: Result<some Any, F>, _ expected: F? = nil, file: String = #file, line: Int = #line) where F: Equatable {
    switch actual {
        case .success: failExpectedActual("Result.failure", actual, file: file, line: line)
        case .failure(let actual):
            if let expected {
                assertEquals(actual, expected, file: file, line: line)
            }
    }
}

private func failExpectedActual(_ expected: Any, _ actual: Any, file: String = #file, line: Int = #line) {
    XCTFail(
        """

        \(file):\(line): Assertion failed
            Expected:
                \(expected)
            Actual:
                \(actual)
        """
    )
}
