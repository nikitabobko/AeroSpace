import Foundation

extension MainActor {
    public static func checkIsolated<T>(_ operation: @MainActor () throws -> T, fileId: MyFileId = #myFileId) rethrows -> T where T: Sendable {
        check(Thread.isMainThread)
        return try assumeIsolated(operation, file: fileId.file, line: fileId.line)
    }
}
