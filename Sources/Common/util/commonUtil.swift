import AppKit
import Darwin
import Foundation

public let unixUserName = NSUserName()
public let mainModeId = "main"

@TaskLocal
public var refreshSessionEvent: RefreshSessionEvent? = nil

@TaskLocal
private var recursionDetectorDuringTermination = false

public func dieT<T>(
    _ __message: String = "",
    file: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    function: String = #function,
) -> T {
    let _message = __message.contains("\n") ? "\n" + __message.prefixLines(with: "    ") : __message
    let thread = Thread.current
    let message =
        """
        Please report to:
            https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs
            Please describe what you did to trigger this error

        Message: \(_message)
        Version: \(aeroSpaceAppVersion)
        Git hash: \(gitHash)
        refreshSessionEvent: \(refreshSessionEvent.prettyDescription)
        Date: \(Date.now)
        Thread name: \(thread.name.prettyDescription)
        Is main thread: \(thread.isMainThread)
        axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken.prettyDescription)
        macOS version: \(ProcessInfo().operatingSystemVersionString)
        Coordinate: \(file):\(line):\(column) \(function)
        recursionDetectorDuringTermination: \(recursionDetectorDuringTermination)
        cli: \(isCli)
        Monitor count: \(NSScreen.screens.count)
        Displays have separate spaces: \(NSScreen.screensHaveSeparateSpaces)

        Stacktrace:
        \(getStringStacktrace())
        """
    if !isUnitTest && isServer {
        showMessageInGui(
            filenameIfConsoleApp: recursionDetectorDuringTermination
                ? "aerospace-runtime-error-recursion.txt"
                : "aerospace-runtime-error.txt",
            title: "AeroSpace Runtime Error",
            message: message,
        )
    }
    if !recursionDetectorDuringTermination {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            defer { semaphore.signal() }
            try await $recursionDetectorDuringTermination.withValue(true) {
                try await terminationHandler.beforeTermination()
            }
        }
        semaphore.wait()
    }
    fatalError("\n" + message)
}

public enum RefreshSessionEvent: Sendable, CustomStringConvertible {
    case globalObserver(String)
    case globalObserverLeftMouseUp
    case menuBarButton
    case hotkeyBinding
    case startup
    case socketServer
    case resetManipulatedWithMouse
    case ax(String)
    case onFocusedMonitorChanged
    case onFocusChanged

    public var isStartup: Bool {
        if case .startup = self { return true } else { return false }
    }

    public var description: String {
        switch self {
            case .ax(let str): "ax(\(str))"
            case .globalObserver(let str): "globalObserver(\(str))"
            case .globalObserverLeftMouseUp: "globalObserverLeftMouseUp"
            case .hotkeyBinding: "hotkeyBinding"
            case .menuBarButton: "menuBarButton"
            case .resetManipulatedWithMouse: "resetManipulatedWithMouse"
            case .socketServer: " socketServer"
            case .startup: "startup"
            case .onFocusedMonitorChanged: "onFocusedMonitorChanged"
            case .onFocusChanged: "onFocusChanged"
        }
    }
}

public func throwT<T>(_ error: Error) throws -> T {
    throw error
}

public func printStacktrace() { print(getStringStacktrace()) }
public func getStringStacktrace() -> String { Thread.callStackSymbols.joined(separator: "\n") }

@inlinable public func die(
    _ message: String = "",
    file: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    function: String = #function,
) -> Never {
    dieT(message, file: file, line: line, column: column, function: function)
}

public func check(
    _ condition: Bool,
    _ message: @autoclosure () -> String = "",
    file: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    function: String = #function,
) {
    if !condition {
        die(message(), file: file, line: line, column: column, function: function)
    }
}

public var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    public static var cliArgsCases: [String] { allCases.map(\.rawValue) }
    public static var unionLiteral: String { cliArgsCases.joinedCliArgs }
}

extension [String] {
    public var joinedCliArgs: String { "(" + self.joined(separator: "|") + ")" }
}

extension Int {
    public func toDouble() -> Double { Double(self) }
}

public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    lhs.merging(rhs) { _, r in r }
}

extension String {
    public func removePrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    public func prependLines(_ prefix: String) -> String {
        split(separator: "\n").map { prefix + $0 }.joined(separator: "\n")
    }
}

extension Bool {
    /// Implication
    /// | a     | b     | a.implies(b) |
    /// |-------|-------|--------------|
    /// | false | false | true         |
    /// | false | true  | true         |
    /// | true  | false | false        |
    /// | true  | true  | true         |
    public func implies(_ mustHold: @autoclosure () -> Bool) -> Bool { !self || mustHold() }
}

extension Double {
    public var squared: Double { self * self }
}

extension Slice {
    public func toArray() -> [Base.Element] { Array(self) }
}

extension URL {
    public func open(with url: URL) {
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

@inlinable
public func allowOnlyCancellationError<T>(isolation: isolated (any Actor)? = #isolation, _ block: () async throws -> sending T) async throws -> sending T {
    do {
        return try await block()
    } catch let e as CancellationError {
        throw e
    } catch {
        die("throws must only be used for CancellationError")
    }
}
