import TOMLKit
import Common

private let windowDetectedParser: [String: any ParserProtocol<RawWindowDetectedCallback>] = [
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
        return array.withIndex.map { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index), &errors) }.filterNotNil()
    } else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.type, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Regex<AnyRegexOutput>> {
    parseString(raw, backtrace).flatMap { parseCaseInsensitiveRegex($0).toParsedToml(backtrace) }
}

private func parseMatcher(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> CallbackMatcher {
    parseTable(raw, CallbackMatcher(), matcherParsers, backtrace, &errors)
}

private func parseWindowDetectedCallback(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowDetectedCallback? {
    var myErrors: [TomlParseError] = []
    let raw = parseTable(raw, RawWindowDetectedCallback(), windowDetectedParser, backtrace, &myErrors)

    if raw.run == nil {
        myErrors.append(.semantic(backtrace, "'run' is mandatory key"))
    }

    let run = raw.run ?? []

    // - 'exec' is prohibited because command-subject isn't yet supported in "exec session"
    // - Commands that change focus are prohibited because the design isn't yet clear
    if !run.allSatisfy({
        let layoutArg = ($0 as? LayoutCommand)?.args.toggleBetween.singleOrNil()
        return layoutArg == .floating || layoutArg == .tiling || $0 is MoveNodeToWorkspaceCommand
    }) {
        myErrors.append(.semantic(backtrace,
            "For now, 'layout floating', 'layout tiling' and 'mode-node-to-workspace' are the only commands that are supported in 'on-window-detected'. " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    let count = run.filter({ $0 is MoveNodeToWorkspaceCommand }).count
    if count >= 1 && !(run.last is MoveNodeToWorkspaceCommand) {
        myErrors.append(.semantic(backtrace,
            "For now, 'move-node-to-workspace' must be the latest instruction in the callback (otherwise it's error-prone). " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    if count > 1 {
        myErrors.append(.semantic(backtrace,
            "For now, 'move-node-to-workspace' can be mentioned only once in 'run' callback. " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"))
    }

    if !myErrors.isEmpty {
        errors += myErrors
        return nil
    }

    return WindowDetectedCallback(
        matcher: raw.matcher ?? CallbackMatcher(),
        checkFurtherCallbacks: raw.checkFurtherCallbacks ?? false,
        run: run
    )
}

private struct RawWindowDetectedCallback: Copyable {
    var matcher: CallbackMatcher?
    var checkFurtherCallbacks: Bool?
    var run: [any Command]?
}
