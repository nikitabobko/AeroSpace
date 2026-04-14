import Foundation

extension MainActor {
    public static func checkIsolated<T>(_ operation: @MainActor () throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T: Sendable {
        check(Thread.isMainThread)
        return try assumeIsolated(operation, file: file, line: line)
    }
}
