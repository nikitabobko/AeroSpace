enum MonitorDescription {
    case sequenceNumber(Int)
    case main
    case secondary
    case pattern(Regex<AnyRegexOutput>)
}
