import Common

struct WindowDetectedCallback: ConvenienceCopyable, Equatable {
    var matcher: WindowDetectedCallbackMatcher = WindowDetectedCallbackMatcher()
    var checkFurtherCallbacks: Bool = false
    var rawRun: [any Command]? = nil

    var run: [any Command] {
        rawRun ?? dieT("ID-46D063B2 should have discarded nil")
    }

    var debugJson: Json {
        var result: [String: Json] = [:]
        result["matcher"] = matcher.debugJson
        if let commands = rawRun {
            result["commands"] = .string(commands.prettyDescription)
        }
        return .dict(result)
    }

    static func == (lhs: WindowDetectedCallback, rhs: WindowDetectedCallback) -> Bool {
        return lhs.matcher == rhs.matcher && lhs.checkFurtherCallbacks == rhs.checkFurtherCallbacks &&
            zip(lhs.run, rhs.run).allSatisfy { $0.equals($1) }
    }
}

struct WindowDetectedCallbackMatcher: ConvenienceCopyable, Equatable {
    var appId: String?
    var appNameRegexSubstring: CaseInsensitiveRegex?
    var windowTitleRegexSubstring: CaseInsensitiveRegex?
    var workspace: String?
    var duringAeroSpaceStartup: Bool?

    var debugJson: Json {
        var resultParts: [String] = []
        if let appId {
            resultParts.append("appId=\"\(appId)\"")
        }
        if let appNameRegexSubstring {
            resultParts.append("appNameRegexSubstring=\"\(appNameRegexSubstring.origin)\"")
        }
        if let windowTitleRegexSubstring {
            resultParts.append("windowTitleRegexSubstring=\"\(windowTitleRegexSubstring.origin)\"")
        }
        if let workspace {
            resultParts.append("workspace=\"\(workspace)\"")
        }
        if let duringAeroSpaceStartup {
            resultParts.append("duringAeroSpaceStartup=\(duringAeroSpaceStartup)")
        }
        return .string(resultParts.joined(separator: ", "))
    }
}

private let windowDetectedParser: [String: any ParserProtocol<WindowDetectedCallback>] = [
    "if": Parser(\.matcher, parseMatcher),
    "check-further-callbacks": Parser(\.checkFurtherCallbacks, parseBool),
    "run": Parser(\.rawRun, upcast { parseCommandOrCommands($0).toParsedConfig($1) }),
]

private let matcherParsers: [String: any ParserProtocol<WindowDetectedCallbackMatcher>] = [
    "app-id": Parser(\.appId, upcast(parseString)),
    "workspace": Parser(\.workspace, upcast(parseString)),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "during-aerospace-startup": Parser(\.duringAeroSpaceStartup, upcast(parseBool)),
]

private func upcast<T>(
    _ fun: @escaping @Sendable (Json, ConfigBacktrace) -> ParsedConfig<T>,
) -> @Sendable (Json, ConfigBacktrace) -> ParsedConfig<T?> {
    { fun($0, $1).map(Optional.init) }
}

func parseOnWindowDetectedArray(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> [WindowDetectedCallback] {
    if let array = raw.asArrayOrNil {
        return array.enumerated().map { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index), &errors) }.filterNotNil()
    } else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.tomlType, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<CaseInsensitiveRegex> {
    parseString(raw, backtrace).flatMap { CaseInsensitiveRegex.new($0).toParsedConfig(backtrace) }
}

private func parseMatcher(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> WindowDetectedCallbackMatcher {
    parseTable(raw, WindowDetectedCallbackMatcher(), matcherParsers, backtrace, &errors)
}

private func parseWindowDetectedCallback(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> WindowDetectedCallback? {
    var myErrors: [ConfigParseError] = []
    let callback = parseTable(raw, WindowDetectedCallback(), windowDetectedParser, backtrace, &myErrors)

    if callback.rawRun == nil { // ID-46D063B2
        myErrors.append(.semantic(backtrace, "'run' is mandatory key"))
    }

    if !myErrors.isEmpty {
        errors += myErrors
        return nil
    }

    return callback
}
