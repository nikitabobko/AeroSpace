// periphery:ignore:all - Those are utils that can become useful any moment
@testable import AppBundle
import Common
import Testing

// todo: get rid of these helpers since we migrated to swift-testing?

func assertTrue(_ actual: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    assertEquals(actual, true, sourceLocation: sourceLocation)
}

func assertFalse(_ actual: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    assertEquals(actual, false, sourceLocation: sourceLocation)
}

// Because assertEquals default messages are unreadable!
// periphery:ignore
func assertNotEquals<T>(_ actual: T, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation) where T: Equatable {
    if actual == expected {
        failExpectedActual("not \(expected)", actual, sourceLocation: sourceLocation)
    }
}

func assertNil(_ actual: Any?, sourceLocation: SourceLocation = #_sourceLocation) {
    if let actual {
        failExpectedActual("nil", actual, sourceLocation: sourceLocation)
    }
}

func assertNotNil(_ actual: Any?, sourceLocation: SourceLocation = #_sourceLocation) {
    if actual == nil {
        failExpectedActual("not nil", "nil", sourceLocation: sourceLocation)
    }
}

func assertEquals<T>(_ actual: T, _ expected: T, additionalMsg: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) where T: Equatable {
    if actual != expected {
        failExpectedActual(expected, actual, additionalMsg: additionalMsg, sourceLocation: sourceLocation)
    }
}


func assertSucc<T>(_ actual: Result<T, some Any>, sourceLocation: SourceLocation = #_sourceLocation) {
    switch actual {
        case .failure: failExpectedActual("Result.success", actual, sourceLocation: sourceLocation)
        case .success: break
    }
}

func assertSucc<T>(_ actual: Result<T, some Any>, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation) where T: Equatable {
    switch actual {
        case .failure: failExpectedActual("Result.success", actual, sourceLocation: sourceLocation)
        case .success(let actual): assertEquals(actual, expected, sourceLocation: sourceLocation)
    }
}
func assertFail<F>(_ actual: Result<some Any, F>, _ expected: F? = nil, sourceLocation: SourceLocation = #_sourceLocation) where F: Equatable {
    switch actual {
        case .success: failExpectedActual("Result.failure", actual, sourceLocation: sourceLocation)
        case .failure(let actual):
            if let expected {
                assertEquals(actual, expected, sourceLocation: sourceLocation)
            }
    }
}

func testParseSingleCommandSucc(_ command: String, _ expected: any CmdArgs, sourceLocation: SourceLocation = #_sourceLocation) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(.cmd(let command)):
            if !command.args.equals(expected) {
                failExpectedActual(expected, command.args, sourceLocation: sourceLocation)
            }
        case .cmd(let shell): failExpectedActual("Parsed as single Command", "Parsed as shell: \(shell.shellOfCommandsDescription)", sourceLocation: sourceLocation)
        case .help: failExpectedActual("Parsed successfully", "Parsed as help", sourceLocation: sourceLocation)
        case .failure(let msg): failExpectedActual("Parsed successfully", "Failed to parse: \(msg.msg)", sourceLocation: sourceLocation)
    }
}

func testParseCommandHelp(_ command: String) {
    let parsed = parseCommand(command)
    switch parsed {
        case .help: break
        default: Issue.record(Comment(rawValue: "Expected to parse to help"))
    }
}

func failExpectedActual(_ expected: Any?, _ actual: Any?, additionalMsg: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    let additionalMsg = additionalMsg.map { "\n    Additional Message:\n        \($0)" } ?? ""
    Issue.record(
        // todo: drop String: LocalizedError conformance and then you can drop this Comment
        Comment(rawValue: """
            Assertion failed\(additionalMsg)
                Expected:
                    \(expected.prettyDescription)
                Actual:
                    \(actual.prettyDescription)
            """),
        sourceLocation: sourceLocation,
    )
}
