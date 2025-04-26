public enum MonitorDescription: Equatable, Sendable {
    case sequenceNumber(Int)
    case main
    case secondary
    case pattern(String, SendableRegex<AnyRegexOutput>)

    public static func == (lhs: MonitorDescription, rhs: MonitorDescription) -> Bool {
        return switch (lhs, rhs) {
            case (.main, .main): true
            case (.secondary, .secondary): true
            case (.sequenceNumber(let a), .sequenceNumber(let b)): a == b
            case (.pattern(let a, _), .pattern(let b, _)): a == b
            default: false
        }
    }

    public static func pattern(_ raw: String) -> MonitorDescription? {
        (try? SendableRegex(raw)).flatMap { .pattern(raw, $0) }
    }
}

public func parseMonitorDescription(_ raw: String) -> Parsed<MonitorDescription> {
    if let int = Int(raw) {
        return int >= 1
            ? .success(.sequenceNumber(int))
            : .failure("Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal")
    }
    if raw == "main" {
        return .success(.main)
    }
    if raw == "secondary" {
        return .success(.secondary)
    }

    return raw.isEmpty
        ? .failure("Empty string is an illegal monitor description")
        : parseCaseInsensitiveRegex(raw).map { MonitorDescription.pattern(raw, .init($0)) }
}

public func parseCaseInsensitiveRegex(_ raw: String) -> Parsed<Regex<AnyRegexOutput>> {
    Result { try Regex(raw) }
        .mapError { e in "Can't parse '\(raw)' regex. \(e.localizedDescription)" }
        .map { $0.ignoresCase() }
}

/// Circumvent Regex not being Sendable by default
public struct SendableRegex<Output>: Sendable {
    public nonisolated(unsafe) let val: Regex<Output>
    init(_ regex: Regex<Output>) { self.val = regex }
    // init(_ str: String) { self.regex = regex }
}

public extension SendableRegex where Output == AnyRegexOutput {
    init(_ pattern: String) throws {
        self = SendableRegex(try Regex(pattern))
    }
}
