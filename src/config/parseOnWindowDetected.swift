import TOMLKit

private let windowDetectedParsers: [String: any ParserProtocol<RawWindowDetectedCallback>] = [
    "if": Parser(\.matcher, parseMatcher),
    "check-further-callbacks": Parser(\.checkFurtherCallbacks, parseBool),
    "run": Parser(\.run, { parseCommandOrCommands($0).toParsedToml($1) }),
]

private let matcherParsers: [String: any ParserProtocol<CallbackMatcher>] = [
    "app-id": Parser(\.appId, parseString),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, parseCasInsensitiveRegex),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, parseCasInsensitiveRegex),
    "during-aerospace-startup": Parser(\.duringAeroSpaceStartup, parseBool),
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

private func parseMatcher(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<CallbackMatcher> {
    guard let table = raw.table else {
        return .failure(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
    }

    var raw = CallbackMatcher()

    for (key, value) in table {
        let backtrace: TomlBacktrace = backtrace + .key(key)
        if let parser = matcherParsers[key] {
            var errors: [TomlParseError] = []
            raw = parser.transformRawConfig(raw, value, backtrace, &errors)
            if !errors.isEmpty {
                return .failure(errors.first!)
            }
        } else {
            return .failure(unknownKeyError(backtrace))
        }
    }

    return .success(raw)
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

    // - 'exec' is prohibited because command-subject isn't yet supported in "exec session"
    // - Commands that change focus are prohibited because the design isn't yet clear
    if !run.allSatisfy({
        let layoutArg = ($0 as? LayoutCommand)?.toggleBetween.singleOrNil()
        return layoutArg == .floating || layoutArg == .tiling || $0 is MoveNodeToWorkspaceCommand
    }) {
        return .failure(.semantic(backtrace,
            "For now, 'layout floating', 'layout tiling' and 'mode-node-to-workspace' are the only commands that are supported in 'on-window-detected'. " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    let count = run.filter({ $0 is MoveNodeToWorkspaceCommand }).count
    if count > 1 || count == 1 && !(run.last is MoveNodeToWorkspaceCommand) {
        return .failure(.semantic(backtrace, "For now, 'move-node-to-workspace' can be mentioned only once in 'run' callback. " +
            "And it must be the latest instruction in the callback (otherwise it's error-prone). " +
            "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    return .success(WindowDetectedCallback(
        matcher: raw.matcher ?? CallbackMatcher(),
        checkFurtherCallbacks: raw.checkFurtherCallbacks ?? false,
        run: run
    ))
}
