import Foundation

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
        cli: \(isCli)

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
    fatalError("\n" + message)
}

public func printStacktrace() { print(getStringStacktrace()) }
public func getStringStacktrace() -> String { Thread.callStackSymbols.joined(separator: "\n") }

@inlinable public func error(
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> Never {
    errorT(message, file: file, line: line, column: column, function: function)
}

public func check(
    _ condition: Bool,
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) {
    if !condition {
        error(message, file: file, line: line, column: column, function: function)
    }
}

@inlinable public func tryCatch<T>(
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function,
    body: () throws -> T
) -> Result<T, Error> {
    Result(catching: body)
}

public var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

public extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static var unionLiteral: String {
        "(" + allCases.map(\.rawValue).joined(separator: "|") + ")"
    }
}

public extension Int {
    func toDouble() -> Double { Double(self) }
}

public extension String {
    func removePrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    func prependLines(_ prefix: String) -> String {
        split(separator: "\n").map { prefix + $0 }.joined(separator: "\n")
    }
}

public extension Double {
    var squared: Double { self * self }
}

public extension Slice {
    func toArray() -> [Base.Element] { Array(self) }
}
