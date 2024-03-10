public enum MonitorDescription {
    case sequenceNumber(Int)
    case main
    case secondary
    case pattern(Regex<AnyRegexOutput>)
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
        : parseCaseInsensitiveRegex(raw).map(MonitorDescription.pattern)
}

public func parseCaseInsensitiveRegex(_ raw: String) -> Parsed<Regex<AnyRegexOutput>> {
    Result { try Regex(raw) }
        .mapError { e in "Can't parse '\(raw)' regex. \(e.localizedDescription)" }
        .map { $0.ignoresCase() }
}
