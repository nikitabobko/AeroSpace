import Common
import Foundation

private let autoRaiseParser: [String: any ParserProtocol<AutoRaiseConfig>] = [
    "enabled": Parser(\.enabled, parseBool),
    "poll-millis": Parser(\.pollMillis, parsePollMillis),
    "ignore-space-changed": Parser(\.ignoreSpaceChanged, parseBool),
    "invert-disable-key": Parser(\.invertDisableKey, parseBool),
    "invert-ignore-apps": Parser(\.invertIgnoreApps, parseBool),
    "ignore-apps": Parser(\.ignoreApps, parseArrayOfStrings),
    "ignore-titles": Parser(\.ignoreTitles, parseIgnoreTitles),
    "stay-focused-bundle-ids": Parser(\.stayFocusedBundleIds, parseArrayOfStrings),
    "disable-key": Parser(\.disableKey, parseAutoRaiseDisableKey),
]

func parseAutoRaise(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> AutoRaiseConfig {
    parseTable(raw, AutoRaiseConfig(), autoRaiseParser, backtrace, &errors)
}

private func parsePollMillis(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<Int> {
    parseInt(raw, backtrace).filter(.semantic(backtrace, "Must be >= 1")) { $0 >= 1 }
}

private func parseAutoRaiseDisableKey(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<AutoRaiseDisableKey> {
    parseString(raw, backtrace).flatMap {
        AutoRaiseDisableKey(rawValue: $0).orFailure(
            .semantic(backtrace, "Can't parse disable-key '\($0)'. Allowed values: control, option, disabled"),
        )
    }
}

// ICU regex validation. NSRegularExpression uses ICU internally, matching the
// regex engine used by AutoRaise.mm's `rangeOfString:options:NSRegularExpressionSearch`.
private func parseIgnoreTitles(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<[String]> {
    parseArrayOfStrings(raw, backtrace).flatMap { patterns in
        for (i, pattern) in patterns.enumerated() {
            do {
                _ = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                return .failure(.semantic(
                    backtrace + .index(i),
                    "Invalid regex '\(pattern)': \(error.localizedDescription)",
                ))
            }
        }
        return .success(patterns)
    }
}
