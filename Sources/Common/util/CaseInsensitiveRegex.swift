/// https://github.com/swiftlang/swift-experimental-string-processing/issues/792
/// https://forums.swift.org/t/should-regex-be-sendable/69529
public struct CaseInsensitiveRegex: Equatable, Sendable {
    public let origin: String
    fileprivate nonisolated(unsafe) let regex: Regex<AnyRegexOutput>

    private init(_ origin: String, _ regex: Regex<AnyRegexOutput>) {
        self.origin = origin
        unsafe self.regex = regex
    }

    public static func new(_ str: String) -> Parsed<CaseInsensitiveRegex> {
        Result { try Regex(str) }
            .mapError { e in "Can't parse \(str.singleQuoted) regex: \(e.localizedDescription)" }
            .map { CaseInsensitiveRegex(str, $0.ignoresCase()) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.origin == rhs.origin }
}

extension String {
    @MainActor public func contains(caseInsensitiveRegex regex: CaseInsensitiveRegex) -> Bool {
        self.contains(unsafe regex.regex)
    }
}
