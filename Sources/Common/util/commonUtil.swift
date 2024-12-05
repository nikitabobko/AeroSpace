import AppKit
import Darwin
import Foundation

public let unixUserName = NSUserName()
public let mainModeId = "main"
private var recursionDetectorDuringFailure: Bool = false

public var refreshSessionEventForDebug: RefreshSessionEvent? = nil

public func errorT<T>(
    _ __message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> T {
    let _message = __message.contains("\n") ? "\n" + __message.indent() : __message
    let message =
        """
        Please report to:
            https://github.com/nikitabobko/AeroSpace/issues
            Please describe what you did to trigger this error

        Message: \(_message)
        Version: \(aeroSpaceAppVersion)
        Git hash: \(gitHash)
        Coordinate: \(file):\(line):\(column) \(function)
        recursionDetectorDuringFailure: \(recursionDetectorDuringFailure)
        cli: \(isCli)
        refreshSessionEvent: \(String(describing: refreshSessionEventForDebug))
        Displays have separate spaces: \(NSScreen.screensHaveSeparateSpaces)

        Stacktrace:
        \(getStringStacktrace())
        """
    if !isUnitTest && isServer {
        showMessageInGui(
            filenameIfConsoleApp: recursionDetectorDuringFailure
                ? "aerospace-runtime-error-recursion.txt"
                : "aerospace-runtime-error.txt",
            title: "AeroSpace Runtime Error",
            message: message
        )
    }
    if !recursionDetectorDuringFailure {
        recursionDetectorDuringFailure = true
        terminationHandler.beforeTermination()
    }
    fatalError("\n" + message)
}

public enum RefreshSessionEvent {
    case globalObserver(String)
    case globalObserverLeftMouseUp
    case menuBarButton
    case hotkeyBinding
    case startup1
    case startup2
    case socketServer
    case resetManipulatedWithMouse
    case ax(String)
}

public func throwT<T>(_ error: Error) throws -> T {
    throw error
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
    _ message: @autoclosure () -> String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) {
    if !condition {
        error(message(), file: file, line: line, column: column, function: function)
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

public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    lhs.merging(rhs) { _, r in r }
}

public extension String {
    func removePrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    func prependLines(_ prefix: String) -> String {
        split(separator: "\n").map { prefix + $0 }.joined(separator: "\n")
    }
}

public extension Bool {
    /// Implication
    /// | a     | b     | a.implies(b) |
    /// |-------|-------|--------------|
    /// | false | false | true         |
    /// | false | true  | true         |
    /// | true  | false | false        |
    /// | true  | true  | true         |
    func implies(_ mustHold: @autoclosure () -> Bool) -> Bool { !self || mustHold() }
}

public extension Double {
    var squared: Double { self * self }
}

public extension Slice {
    func toArray() -> [Base.Element] { Array(self) }
}

public extension URL {
    func open(with url: URL) {
        NSWorkspace.shared.open([self], withApplicationAt: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

public func printStderr(_ msg: String) {
    fputs(msg + "\n", stderr)
}

public func cliError(_ message: String = "") -> Never {
    cliErrorT(message)
}

public func cliErrorT<T>(_ message: String = "") -> T {
    printStderr(message)
    exit(1)
}
