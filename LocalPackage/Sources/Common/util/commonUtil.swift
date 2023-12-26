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
) -> Result<T, AeroError> {
    do {
        return try .success(body())
    } catch let e {
        return .failure(AeroError(
            "Swift exception: \(e.localizedDescription)",
            file: file,
            line: line,
            column: column,
            function: function
        ))
    }
}

public struct AeroError: Error {
    public let msg: String
    public let file: String
    public let line: Int
    public let column: Int
    public let function: String

    public init(
        _ msg: String,
        file: String,
        line: Int,
        column: Int,
        function: String
    ) {
        self.msg = msg
        self.file = file
        self.line = line
        self.column = column
        self.function = function
    }

    public func throwIt(_ msgPrefix: String = "") -> Never {
        error(msgPrefix + msg, file: file, line: line, column: column, function: function)
    }
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
}

public extension Double {
    var squared: Double { self * self }
}

public extension Slice {
    func toArray() -> [Base.Element] { Array(self) }
}
