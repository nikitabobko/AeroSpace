// periphery:ignore:all - Those are utils that can become useful any moment
@testable import AppBundle
import Common
import XCTest

func assertTrue(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertEquals(actual, true, file: file, line: line)
}

func assertFalse(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertEquals(actual, false, file: file, line: line)
}

// Because assertEquals default messages are unreadable!
// periphery:ignore
func assertNotEquals<T>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) where T: Equatable {
    if actual == expected {
        failExpectedActual("not \(expected)", actual, file: file, line: line)
    }
}

func assertNil(_ actual: Any?, file: StaticString = #filePath, line: UInt = #line) {
    if let actual {
        failExpectedActual("nil", actual, file: file, line: line)
    }
}

func assertNotNil(_ actual: Any?, file: StaticString = #filePath, line: UInt = #line) {
    if actual == nil {
        failExpectedActual("not nil", "nil", file: file, line: line)
    }
}

func assertEquals<T>(_ actual: T, _ expected: T, additionalMsg: String? = nil, file: StaticString = #filePath, line: UInt = #line) where T: Equatable {
    if actual != expected {
        failExpectedActual(expected, actual, additionalMsg: additionalMsg, file: file, line: line)
    }
}


func assertSucc<T>(_ actual: Result<T, some Any>, file: StaticString = #filePath, line: UInt = #line) {
    switch actual {
        case .failure: failExpectedActual("Result.success", actual, file: file, line: line)
        case .success: break
    }
}

func assertSucc<T>(_ actual: Result<T, some Any>, _ expected: T, file: StaticString = #filePath, line: UInt = #line) where T: Equatable {
    switch actual {
        case .failure: failExpectedActual("Result.success", actual, file: file, line: line)
        case .success(let actual): assertEquals(actual, expected, file: file, line: line)
    }
}
func assertFail<F>(_ actual: Result<some Any, F>, _ expected: F? = nil, file: StaticString = #filePath, line: UInt = #line) where F: Equatable {
    switch actual {
        case .success: failExpectedActual("Result.failure", actual, file: file, line: line)
        case .failure(let actual):
            if let expected {
                assertEquals(actual, expected, file: file, line: line)
            }
    }
}

func testParseSingleCommandSucc(_ command: String, _ expected: any CmdArgs, file: StaticString = #filePath, line: UInt = #line) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(.cmd(let command)):
            if !command.args.equals(expected) {
                failExpectedActual(expected, command.args, file: file, line: line)
            }
        case .cmd(let shell): failExpectedActual("Parsed as single Command", "Parsed as shell: \(shell.shellOfCommandsDescription)", file: file, line: line)
        case .help: failExpectedActual("Parsed successfully", "Parsed as help", file: file, line: line)
        case .failure(let msg): failExpectedActual("Parsed successfully", "Failed to parse: \(msg.msg)", file: file, line: line)
    }
}

func testParseCommandHelp(_ command: String) {
    let parsed = parseCommand(command)
    switch parsed {
        case .help: break
        default: XCTFail("Expected to parse to help")
    }
}

func failExpectedActual(_ expected: Any?, _ actual: Any?, additionalMsg: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
    let additionalMsg = additionalMsg.map { "\n    Additional Message:\n        \($0)" } ?? ""
    XCTFail(
        """
        Assertion failed\(additionalMsg)
            Expected:
                \(expected.prettyDescription)
            Actual:
                \(actual.prettyDescription)
        """,
        file: file,
        line: line,
    )
}
