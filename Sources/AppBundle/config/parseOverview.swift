import AppKit
import Common

private let overviewParserTable: [String: any ParserProtocol<OverviewConfig>] = [
    "hold-modifier": Parser(\.holdModifier, parseHoldModifier),
    "hold-delay-ms": Parser(\.holdDelayMs, parseHoldDelayMs),
]

func parseOverview(_ rawConfig: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> OverviewConfig {
    parseTable(rawConfig, OverviewConfig(), overviewParserTable, backtrace, &c)
}

/// The syntax is the same as the modifiers part of a binding ('alt', 'alt-shift'). 'none' disables the feature
private func parseHoldModifier(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<NSEvent.ModifierFlags?> {
    parseString(raw, backtrace).flatMap { raw -> ResOrConfigParseDiagnostic<NSEvent.ModifierFlags?> in
        if raw == "none" { return .success(nil) }
        return raw.split(separator: "-")
            .mapAllOrFailure { modifiersMap[String($0)].toResult(.init(backtrace, "Can't parse modifiers in '\(raw)'")) }
            .map { NSEvent.ModifierFlags($0) }
    }
}

private func parseHoldDelayMs(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Int> {
    parseInt(raw, backtrace)
        .filter(.init(backtrace, "hold-delay-ms must be in [0, 5000] range")) { (0 ... 5000).contains($0) }
}
