import Common
import TOMLKit

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
    var appNameRegexSubstring: Regex<AnyRegexOutput>?
    var windowTitleRegexSubstring: Regex<AnyRegexOutput>?
    var workspace: String?
    var duringAeroSpaceStartup: Bool?

    var debugJson: Json {
        var resultParts: [String] = []
        if let appId {
            resultParts.append("appId=\"\(appId)\"")
        }
        if appNameRegexSubstring != nil {
            resultParts.append("appNameRegexSubstrin=Regex")
        }
        if windowTitleRegexSubstring != nil {
            resultParts.append("windowTitleRegexSubstring=Regex")
        }
        if let workspace {
            resultParts.append("workspace=\"\(workspace)\"")
        }
        if let duringAeroSpaceStartup {
            resultParts.append("duringAeroSpaceStartup=\(duringAeroSpaceStartup)")
        }
        return .string(resultParts.joined(separator: ", "))
    }

    static func == (lhs: WindowDetectedCallbackMatcher, rhs: WindowDetectedCallbackMatcher) -> Bool {
        check(
            lhs.appNameRegexSubstring == nil &&
                lhs.windowTitleRegexSubstring == nil &&
                rhs.appNameRegexSubstring == nil &&
                rhs.windowTitleRegexSubstring == nil,
        )
        return lhs.appId == rhs.appId
    }
}

private let windowDetectedParser: [String: any ParserProtocol<WindowDetectedCallback>] = [
    "if": Parser(\.matcher, parseMatcher),
    "check-further-callbacks": Parser(\.checkFurtherCallbacks, parseBool),
    "run": Parser(\.rawRun, upcast { parseCommandOrCommands($0).toParsedToml($1) }),
]

private let matcherParsers: [String: any ParserProtocol<WindowDetectedCallbackMatcher>] = [
    "app-id": Parser(\.appId, upcast(parseString)),
    "workspace": Parser(\.workspace, upcast(parseString)),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "during-aerospace-startup": Parser(\.duringAeroSpaceStartup, upcast(parseBool)),
]

private func upcast<T>(_ fun: @escaping @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) -> @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T?> {
    { fun($0, $1).map { $0 } }
}

func parseOnWindowDetectedArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [WindowDetectedCallback] {
    if let array = raw.array {
        return array.enumerated().map { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index), &errors) }.filterNotNil()
    } else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.type, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Regex<AnyRegexOutput>> {
    parseString(raw, backtrace).flatMap { parseCaseInsensitiveRegex($0).toParsedToml(backtrace) }
}

private func parseMatcher(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowDetectedCallbackMatcher {
    parseTable(raw, WindowDetectedCallbackMatcher(), matcherParsers, backtrace, &errors)
}

private func parseWindowDetectedCallback(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowDetectedCallback? {
    var myErrors: [TomlParseError] = []
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
