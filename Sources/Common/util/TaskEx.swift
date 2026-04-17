// _inheritActorContext is a private attribute that comes from Task init.
// To find the original, run:
// grep -H 'public init.*operation' "$(find /Applications/Xcode.app -path '*/MacOSX*/_Concurrency.swiftmodule/arm64e-apple-macos.swiftinterface')"
//
// https://github.com/swiftlang/swift/blob/main/docs/ReferenceGuides/UnderscoredAttributes.md
extension Task  /*This comment breaks the regex in lint.sh*/ {
    @discardableResult
    public static func startUnstructured(
        @_inheritActorContext _ operation: sending @escaping @isolated(any) () async -> Success,
    ) -> Task<Success, Failure> where Failure == Never, Success == () {
        .init(operation: operation)
    }

    @discardableResult
    public static func startUnstructured(
        @_inheritActorContext _ operation: sending @escaping @isolated(any) () async throws -> Success,
    ) -> Task<Success, Failure> where Failure == any Error, Success == () {
        .init(operation: operation)
    }
}
