import Foundation
import Common

private var recursionDetectorDuringFailure: Bool = false

public func errorT<T>(
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> T {
    let message =
        """
        ###############################
        ### AEROSPACE RUNTIME ERROR ###
        ###############################

        Please report to:
            https://github.com/nikitabobko/AeroSpace/issues/new

        Message: \(message)
        Version: \(aeroSpaceAppVersion)
        Git hash: \(gitHash)
        Coordinate: \(file):\(line):\(column) \(function)
        recursionDetectorDuringFailure: \(recursionDetectorDuringFailure)

        Stacktrace:
        \(getStringStacktrace())
        """
    if !isUnitTest && isServer {
        showMessageToUser(
            filename: recursionDetectorDuringFailure ? "runtime-error-recursion.txt" : "runtime-error.txt",
            message: message
        )
    }
    if !recursionDetectorDuringFailure {
        recursionDetectorDuringFailure = true
        terminationHandler.beforeTermination()
    }
    fatalError(message)
}

func printStacktrace() { print(getStringStacktrace()) }
func getStringStacktrace() -> String { Thread.callStackSymbols.joined(separator: "\n") }

@inlinable public func error(
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> Never {
    errorT(message, file: file, line: line, column: column, function: function)
}

public var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }
