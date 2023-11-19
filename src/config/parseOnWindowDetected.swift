import TOMLKit

private let windowDetectedParsers: [String: any ParserProtocol<RawWindowDetectedCallback>] = [
    "app-id": Parser(\.appId, parseString),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, parseCasInsensitiveRegex),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, parseCasInsensitiveRegex),
    "run": Parser(\.run, { parseCommandOrCommands($0).toParsedToml($1) }),
]

func parseOnWindowDetectedArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [WindowDetectedCallback] {
    if let array = raw.array {
        return array.withIndex.mapToResult(appendErrorsTo: &errors) { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index)) }
    } else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.type, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Regex<AnyRegexOutput>> {
    parseString(raw, backtrace).flatMap { parseCaseInsensitiveRegex($0).toParsedToml(backtrace) }
}

private func parseWindowDetectedCallback(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<WindowDetectedCallback> {
    guard let table = raw.table else {
        return .failure(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
    }

    var raw = RawWindowDetectedCallback()

    for (key, value) in table {
        let backtrace: TomlBacktrace = backtrace + .key(key)
        if let parser = windowDetectedParsers[key] {
            var errors: [TomlParseError] = []
            raw = parser.transformRawConfig(raw, value, backtrace, &errors)
            if !errors.isEmpty {
                return .failure(errors.first!)
            }
        } else {
            return .failure(unknownKeyError(backtrace))
        }
    }

    guard let run = raw.run else {
        return .failure(.semantic(backtrace, "'run' is mandatory key"))
    }

    if run.contains(where: \.isExec) {
        return .failure(.semantic(backtrace, "'exec' commands are not yet supported in 'on-window-detected'. " +
            "Please report your use-cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    return .success(WindowDetectedCallback(
        appId: raw.appId,
        appNameRegexSubstring: raw.appNameRegexSubstring,
        windowTitleRegexSubstring: raw.windowTitleRegexSubstring,
        run: run
    ))
}
