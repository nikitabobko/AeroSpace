import Common
import Foundation

private let dwindleParser: [String: any ParserProtocol<DwindleConfig>] = [
    "force-split": Parser(\.forceSplit, parseForceSplit),
    "smart-split": Parser(\.smartSplit, parseBool),
    "preserve-split": Parser(\.preserveSplit, parseBool),
    "default-split-ratio": Parser(\.defaultSplitRatio, parseDefaultSplitRatio),
    "split-width-multiplier": Parser(\.splitWidthMultiplier, parseSplitWidthMultiplier),
    "no-gaps-when-only": Parser(\.noGapsWhenOnly, parseBool),
    "use-active-for-splits": Parser(\.useActiveForSplits, parseBool),
]

func parseDwindle(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> DwindleConfig {
    parseTable(raw, DwindleConfig(), dwindleParser, backtrace, &errors)
}

private func parseForceSplit(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<ForceSplit> {
    parseString(raw, backtrace).flatMap {
        ForceSplit(rawValue: $0).orFailure(
            .semantic(backtrace, "Can't parse force-split '\($0)'. Allowed values: auto, first, second"),
        )
    }
}

private func parseDefaultSplitRatio(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<CGFloat> {
    parseDouble(raw, backtrace)
        .filter(.semantic(backtrace, "default-split-ratio must be in the open interval (0.0, 1.0)")) { $0 > 0.0 && $0 < 1.0 }
        .map { CGFloat($0) }
}

private func parseSplitWidthMultiplier(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<CGFloat> {
    parseDouble(raw, backtrace)
        .filter(.semantic(backtrace, "split-width-multiplier must be > 0")) { $0 > 0.0 }
        .map { CGFloat($0) }
}

/// Parses a TOML float. Accepts integers transparently (TOML's `1` is a valid float
/// for fields like `split-width-multiplier`).
private func parseDouble(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Double> {
    raw.asDoubleOrNil.orFailure(expectedActualTypeError(expected: .float, actual: raw.tomlType, backtrace))
}
